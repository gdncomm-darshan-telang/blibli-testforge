// The command queue the running app polls, hosted by this server.
//
// It lives here rather than in a separate process because this server is the
// only thing that writes commands, ships in the same repo as the app, and is
// already launched by `.mcp.json` — so an iOS developer who clones and opens
// Claude Code has the live channel with nothing else to install. The browser
// lens's standalone sidecar remains the way to drive a browser.
//
// Deliberately NOT port 8787. That is the web sidecar's, and it serves
// `/ingest` and `/scenarios` as well as the queue. Binding it here would take
// the port on whichever process started first — usually this one, since an MCP
// client launches it automatically — and the extension's traces would then POST
// into a 404 and vanish with nothing to read.
import { createServer } from "node:http";
const PORT = Number(process.env.NETWORKLENS_CONTROL_PORT || 8788);
/** Bounded so an app that never collects cannot grow this without limit. */
const MAX_COMMANDS = 100;
const MAX_RESULTS = 100;
const MAX_BODY_BYTES = 4 * 1_048_576;
/** The app polls every 2 s; a target silent for longer than this is treated as not running. */
const TARGET_FRESH_MS = 5_000;
class CommandQueue {
    commands = [];
    results = new Map();
    nextID = 1;
    server = null;
    pollers = new Map();
    /** True once this process owns the port, so callers skip the HTTP round trip to themselves. */
    get isHosting() {
        return this.server !== null;
    }
    get endpoint() {
        return `http://127.0.0.1:${PORT}`;
    }
    enqueue(body) {
        if (this.commands.length >= MAX_COMMANDS)
            this.commands.shift();
        const id = this.nextID++;
        this.commands.push({ ...body, id });
        return id;
    }
    /**
     * Draining is destructive on purpose: a command applied twice toggles something back off.
     *
     * A command carrying `device` goes only to the app polling from that simulator, so a second simulator running the
     * same app cannot take it. An app that sends no identity (before the QA fork's phase D) gets a targeted command
     * only while the target itself is not polling — otherwise an old build on another simulator could win the race.
     */
    drain(poller) {
        const device = poller?.device ?? null;
        this.notePoll(device, poller?.bundle ?? null, poller?.pid ?? null);
        const taken = [];
        const kept = [];
        for (const command of this.commands) {
            const target = typeof command.device === "string" ? command.device : null;
            const isForThisPoller = !target || target === device || (!device && !this.isPolling(target));
            (isForThisPoller ? taken : kept).push(command);
        }
        this.commands = kept;
        return taken;
    }
    /** A command nobody collected in time is withdrawn, so it cannot land late and surprise someone. */
    withdraw(id) {
        const before = this.commands.length;
        this.commands = this.commands.filter((command) => command.id !== id);
        return this.commands.length < before;
    }
    /** Most recent first; `device` null is an app that does not say which simulator it is on. */
    get recentPollers() {
        return [...this.pollers.values()].sort((lhs, rhs) => rhs.at - lhs.at);
    }
    isPolling(device) {
        const last = this.pollers.get(device);
        return Boolean(last && Date.now() - last.at < TARGET_FRESH_MS);
    }
    notePoll(device, bundle, pid) {
        this.pollers.set(device ?? "unknown", { device, bundle, pid, at: Date.now() });
        if (this.pollers.size > 20) {
            const oldest = this.recentPollers.at(-1);
            if (oldest)
                this.pollers.delete(oldest.device ?? "unknown");
        }
    }
    recordResult(body) {
        this.results.set(body.id, { ...body, at: new Date().toISOString() });
        if (this.results.size > MAX_RESULTS) {
            const oldest = this.results.keys().next().value;
            if (oldest !== undefined)
                this.results.delete(oldest);
        }
    }
    result(id) {
        return this.results.get(id) ?? null;
    }
    /**
     * Binds the port, or reports why it could not.
     *
     * A port already taken is the ordinary case, not a failure: another editor
     * window is running its own copy of this server, and its queue serves the app
     * just as well. The caller falls back to speaking to it over HTTP.
     */
    async listen() {
        if (this.server)
            return true;
        const server = createServer((request, response) => this.handle(request, response));
        return new Promise((settle) => {
            server.once("error", () => {
                server.close();
                settle(false);
            });
            server.listen(PORT, "127.0.0.1", () => {
                this.server = server;
                // Never hold the process open: stdio closing is what ends this server,
                // and a listening socket would otherwise keep it alive as an orphan.
                server.unref();
                settle(true);
            });
        });
    }
    close() {
        this.server?.close();
        this.server = null;
    }
    handle(request, response) {
        const url = new URL(request.url, "http://localhost");
        const reply = (code, value) => {
            response.writeHead(code, {
                "content-type": "application/json",
                "access-control-allow-origin": "*",
                "access-control-allow-headers": "content-type",
                "access-control-allow-methods": "POST, GET, OPTIONS",
            });
            response.end(JSON.stringify(value));
        };
        if (request.method === "OPTIONS")
            return reply(204, {});
        if (request.method === "GET" && url.pathname === "/health") {
            const pollers = this.recentPollers.map((entry) => ({ ...entry, msAgo: Date.now() - entry.at }));
            return reply(200, { ok: true, hostedBy: "networklens-mcp", queued: this.commands.length, pollers });
        }
        if (request.method === "GET" && url.pathname === "/commands") {
            const poller = { device: url.searchParams.get("device"), bundle: url.searchParams.get("bundle"), pid: url.searchParams.get("pid") };
            return reply(200, { ok: true, commands: this.drain(poller) });
        }
        if (request.method === "GET" && url.pathname === "/result") {
            const found = this.result(Number(url.searchParams.get("id")));
            return reply(200, { ok: true, result: found, pending: !found });
        }
        if (request.method === "POST" && (url.pathname === "/result" || url.pathname === "/command")) {
            const chunks = [];
            let size = 0;
            request.on("data", (chunk) => {
                size += chunk.length;
                if (size > MAX_BODY_BYTES) {
                    request.destroy();
                    return;
                }
                chunks.push(chunk);
            });
            request.on("end", () => {
                try {
                    const body = JSON.parse(Buffer.concat(chunks).toString("utf8"));
                    if (url.pathname === "/result") {
                        this.recordResult(body);
                        return reply(200, { ok: true });
                    }
                    const id = this.enqueue(body);
                    return reply(200, { ok: true, id, queued: this.commands.length });
                }
                catch (error) {
                    return reply(400, { ok: false, error: String(error?.message ?? error) });
                }
            });
            return;
        }
        reply(404, { ok: false, error: "not found" });
    }
}
export const queue = new CommandQueue();

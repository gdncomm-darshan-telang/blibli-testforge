// Drives the rules in a running app, instead of leaving them in a file it reads at launch.
//
// The app polls the sidecar; nothing here reaches the app directly. That
// indirection is the point — the MCP server is spawned and killed by its
// client, the app is killed by whoever is testing, and a queue survives both
// being down at once in a way a connection cannot.
import { queue } from "./control-queue.js";
/**
 * An explicit sidecar, for pointing at one that is already running.
 *
 * Set it and this server hosts nothing and speaks HTTP to that address — the
 * way to drive an app from the browser lens's own sidecar. Unset, this server
 * hosts the queue itself, which is what makes a fresh clone work with nothing
 * else installed.
 */
const EXPLICIT_SIDECAR = process.env.NETWORKLENS_SIDECAR?.replace(/\/$/, "") || null;
let hosting = null;
/** Bound once, lazily: a server that never issues a command should not open a port. */
async function ready() {
    if (EXPLICIT_SIDECAR)
        return EXPLICIT_SIDECAR;
    hosting ??= queue.listen();
    await hosting;
    return queue.endpoint;
}
/** The app collects on a 2s timer, so anything under that reports a miss on a
 *  command that was about to land. Double it, plus a round trip. */
const ANSWER_TIMEOUT_MS = 6_000;
const POLL_MS = 250;
/** One HTTP call that treats a dead sidecar as an answer rather than a throw. */
async function call(path, init) {
    const base = await ready();
    try {
        const response = await fetch(`${base}${path}`, {
            ...init,
            signal: AbortSignal.timeout(2_000),
        });
        if (!response.ok)
            return null;
        return await response.json();
    }
    catch {
        return null;
    }
}
export async function isSidecarUp() {
    return (await call("/health")) !== null;
}
/** Where commands are going, for anything that has to explain itself to a human. */
export async function controlEndpoint() {
    const base = await ready();
    return queue.isHosting ? `${base} (hosted here)` : base;
}
/**
 * Queues one command and waits for the app to report back on it.
 *
 * Hosting the queue in this process is the common case, and going through
 * loopback to reach an object in the same heap would only add a way to fail.
 */
export async function sendCommand(body) {
    const base = await ready();
    const local = queue.isHosting && !EXPLICIT_SIDECAR;
    // Pinned to one simulator, like trace and session resolution: the command goes to that simulator's app only.
    const device = process.env.NETWORKLENS_UDID;
    if (device && body.device === undefined)
        body = { ...body, device };
    let id;
    if (local) {
        id = queue.enqueue(body);
    }
    else {
        const queued = await call("/command", {
            method: "POST",
            headers: { "content-type": "application/json" },
            body: JSON.stringify(body),
        });
        if (!queued?.ok || typeof queued.id !== "number") {
            return { ok: false, reachable: false, error: `no queue on ${base}` };
        }
        id = queued.id;
    }
    const deadline = Date.now() + ANSWER_TIMEOUT_MS;
    while (Date.now() < deadline) {
        await new Promise((wait) => setTimeout(wait, POLL_MS));
        const result = local ? queue.result(id) : (await call(`/result?id=${id}`))?.result;
        if (result) {
            if (result.error)
                return { ok: false, reachable: true, error: String(result.error) };
            return { ok: true, reachable: true, outcome: result.value };
        }
    }
    if (local)
        queue.withdraw(id);
    return { ok: false, reachable: false, error: device ? `queued for ${device}, but no app there collected it` : "queued, but no app collected it" };
}
/** The one verb every write tool uses: install rules, drop rules, set the master switch. */
export async function liveEdit(edit) {
    return sendCommand({ kind: "edit", ...edit });
}
export async function liveState() {
    return sendCommand({ kind: "state" });
}
/**
 * The sentence a write ends on when it landed in the running app.
 *
 * The app autosaves its rules, so the session file catches up on its own —
 * there is nothing for the caller to do and nothing to relaunch for.
 */
export const LIVE_NOTE = "Live in the running app — no relaunch needed.";
/** Said when the app answered with a refusal, so the caller does not go and write the file instead. */
export function liveRefusal(result) {
    return [
        `The running app refused this: ${result.error}`,
        "",
        "It is live and owns its own rules, so writing the session file would be undone by its next autosave.",
    ].join("\n");
}

// One live state for every open page (D-077). The state is a set of named slices. A slice is either
// read on demand (`poke` after something changed it, or an event the hub watches) or probed on a
// cadence when it lives outside the dashboard (the simulator, git, NetworkLens) — and only while at
// least one page is connected. A slice is pushed only when its JSON actually changed, so pages never
// poll and never re-render for nothing.
import { EventEmitter } from "node:events";

export class StateHub extends EventEmitter {
	constructor({ throttleMs = 250, now = () => Date.now() } = {}) {
		super();
		this.setMaxListeners(200);
		this.throttleMs = throttleMs;
		this.now = now;
		this.version = 0;
		this.slices = new Map(); // name → { read?, everyMs?, value, json, version, at, error, timer, inFlight, pokeTimer, isDirty }
		this.subscribers = new Set();
	}

	/** `read()` → value (async ok). `everyMs` probes it while pages are connected. */
	define(name, { read, everyMs = null, initial = undefined } = {}) {
		this.slices.set(name, { read, everyMs, value: initial, json: initial === undefined ? undefined : JSON.stringify(initial), version: 0, at: null, error: null, timer: null, inFlight: null, pokeTimer: null, isDirty: false });
		if (this.subscribers.size) this.#start(name);
		return this;
	}

	/** Re-reads `name` whenever `emitter` emits `event`. */
	watch(name, emitter, event = "change") {
		emitter.on(event, () => this.poke(name));
		return this;
	}

	/** Pushed slices (narration, usage) are set directly instead of read. */
	set(name, value) {
		const slice = this.slices.get(name);
		if (!slice) throw new Error(`unknown slice ${name}`);
		this.#store(name, slice, value, null);
	}

	/** Asks for a re-read soon; bursts within `throttleMs` become one read. */
	poke(name) {
		const slice = this.slices.get(name);
		if (!slice?.read) return;
		if (slice.pokeTimer) return;
		slice.pokeTimer = setTimeout(() => {
			slice.pokeTimer = null;
			this.refresh(name).catch(() => {});
		}, this.throttleMs);
	}

	/** Reads `name` now. A read already in flight is re-run once it ends, so a poke is never lost. */
	async refresh(name) {
		const slice = this.slices.get(name);
		if (!slice?.read) return;
		if (slice.inFlight) {
			slice.isDirty = true;
			return slice.inFlight;
		}
		slice.inFlight = (async () => {
			try {
				this.#store(name, slice, await slice.read(), null);
			} catch (error) {
				this.#store(name, slice, slice.value, error.message ?? String(error));
			}
		})().finally(() => {
			slice.inFlight = null;
			if (slice.isDirty) {
				slice.isDirty = false;
				this.refresh(name).catch(() => {});
			}
		});
		return slice.inFlight;
	}

	snapshot() {
		const slices = {};
		for (const [name, slice] of this.slices) slices[name] = { value: slice.value ?? null, version: slice.version, at: slice.at, error: slice.error, isPending: slice.at === null };
		return { version: this.version, slices };
	}

	/** `listener({slice, value, version, at, error})` for every change. Returns unsubscribe. */
	subscribe(listener) {
		this.subscribers.add(listener);
		if (this.subscribers.size === 1) for (const name of this.slices.keys()) this.#start(name);
		return () => {
			this.subscribers.delete(listener);
			if (!this.subscribers.size) for (const name of this.slices.keys()) this.#stop(name);
		};
	}

	/** Stops every probe (tests, shutdown). */
	close() {
		for (const name of this.slices.keys()) this.#stop(name);
		for (const slice of this.slices.values()) clearTimeout(slice.pokeTimer);
		this.subscribers.clear();
	}

	#start(name) {
		const slice = this.slices.get(name);
		if (!slice.read) return;
		// A page that connects gets fresh values for slices that only change outside the dashboard.
		if (slice.everyMs || slice.at === null) this.refresh(name).catch(() => {});
		if (slice.everyMs && !slice.timer) {
			slice.timer = setInterval(() => !slice.inFlight && this.refresh(name).catch(() => {}), slice.everyMs);
			slice.timer.unref?.();
		}
	}

	#stop(name) {
		const slice = this.slices.get(name);
		clearInterval(slice.timer);
		slice.timer = null;
	}

	#store(name, slice, value, error) {
		const json = JSON.stringify(value ?? null);
		const at = this.now();
		const isFirst = slice.at === null;
		slice.at = at;
		if (!isFirst && json === slice.json && error === slice.error) return;
		Object.assign(slice, { value, json, error, version: ++this.version });
		const patch = { slice: name, value: value ?? null, version: slice.version, at, error };
		for (const listener of this.subscribers) listener(patch);
		this.emit("patch", patch);
	}
}

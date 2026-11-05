// R3d (D-089): the Mac app outlines, on the Simulator, the element a replay step is about to act on.
// Reading that frame costs ~1.6 s per action step (the runner waits for the frame to settle), so it only
// happens while a Mac app holds a lease, which it renews every minute while the outline is switched on.
// A shared setup routine's steps (Open Home, log in) are never outlined: the busy banner covers them.

const LEASE_MS = 90_000;
// The element should already be on screen for these; a step that waits for one (waitFor, scrollTo)
// would make the frame read wait too, holding up the step itself.
const FRAME_KINDS = new Set(["tap", "type", "typeSecret", "scrollToTop", "assert"]);
// Below ~1.5 s the runner answers "exists but never laid out a valid frame" even for a settled element.
const FRAME_WAIT_S = 2;

/** `frame` from the runner arrives as `{ value: { x, y, width, height } }`; anything else is no frame. */
export function frameOf(outcome) {
	const value = outcome?.value ?? outcome;
	if (!value || outcome?.error) return null;
	const numbers = ["x", "y", "width", "height"].map((key) => Number(value[key]));
	if (numbers.some((number) => !Number.isFinite(number))) return null;
	const [x, y, width, height] = numbers;
	return width > 0 && height > 0 ? { x, y, width, height } : null;
}

export function createStepFrames({ fetchFrame, now = Date.now }) {
	let leaseUntil = 0;
	return {
		lease(isOn) {
			leaseUntil = isOn ? now() + LEASE_MS : 0;
			return { isOn: this.isWanted(), until: leaseUntil ? new Date(leaseUntil).toISOString() : null };
		},
		isWanted() {
			return now() < leaseUntil;
		},
		/** The frame for a step about to run, or null when not wanted, not an on-screen action, or not found. */
		async frameFor(step) {
			if (!this.isWanted() || !step?.identifier || step.from || !FRAME_KINDS.has(step.do)) return null;
			try {
				return frameOf(await fetchFrame(step.identifier, FRAME_WAIT_S));
			} catch {
				return null;
			}
		},
	};
}

// D-119: replays work on any device size. Nothing here is measured in points: where an element sits is
// judged against fractions of the visible window, and scrolling uses the runner's own relative swipe
// (75 % → 20 % of the scroll view). A smaller phone just takes more nudges; a bigger one takes none.
import { frameOf } from "./step-frames.js";

/** Top share of the window a nav bar / status bar may cover; an element whose centre is here is "above". */
export const TOP_BAND = 0.12;
/** Bottom share a tab bar / home indicator may cover; an element whose centre is here is "below". */
export const BOTTOM_BAND = 0.12;
/** Nudges are capped by progress, not distance: stop when the element's frame stops moving. */
export const MAX_NUDGES = 12;

/** `deviceInfo` → `{ width, height }` in points, or null. */
export function viewportOf(outcome) {
	const value = outcome?.value ?? outcome;
	const match = /^(\d+(?:\.\d+)?)x(\d+(?:\.\d+)?)$/.exec(String(value?.screenPoints ?? ""));
	if (!match || outcome?.error) return null;
	return { width: Number(match[1]), height: Number(match[2]) };
}

/**
 * "above" | "below" | "left" | "right" | "inView" for an element frame against the window, using its centre and
 * the bands above — the same answer on a 4.7-inch and a 6.9-inch screen.
 */
export function placement(frame, viewport) {
	if (!frame || !viewport?.height || !viewport?.width) return "unknown";
	const midX = frame.x + frame.width / 2;
	const midY = frame.y + frame.height / 2;
	if (midY < viewport.height * TOP_BAND) return "above";
	if (midY > viewport.height * (1 - BOTTOM_BAND)) return "below";
	if (midX < 0) return "left";
	if (midX > viewport.width) return "right";
	return "inView";
}

/** The swipe that brings content in from where the element is (content moves the opposite way to the finger). */
export function swipeToward(where) {
	return { below: "up", above: "down", right: "left", left: "right" }[where] ?? null;
}

/**
 * Scrolls until the element identified by `locator` (`{ identifier?, within?, elementType?, index? }`) is in view.
 * `send(command)` returns the runner's unwrapped outcome. Resolves to `{ inView, nudges, where }`.
 */
export async function bringIntoView(locator, { send, viewport }) {
	if (!(locator?.identifier || locator?.within) || !viewport) return { inView: false, nudges: 0, where: "unknown" };
	await send({ kind: "dismissKeyboard" }).catch(() => null);
	let previous = null;
	let where = "unknown";
	for (let nudges = 0; nudges <= MAX_NUDGES; nudges++) {
		const frame = frameOf(await send({ kind: "getFrame", ...locator, timeout: 2 }).catch(() => null));
		where = placement(frame, viewport);
		if (where === "inView") return { inView: true, nudges, where };
		const direction = swipeToward(where);
		const isStuck = previous && frame && previous.x === frame.x && previous.y === frame.y;
		if (!direction || isStuck || nudges === MAX_NUDGES) return { inView: false, nudges, where };
		previous = frame;
		await send({ kind: "swipe", direction });
	}
	return { inView: false, nudges: MAX_NUDGES, where };
}

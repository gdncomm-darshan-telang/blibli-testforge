// F5 (D-195): Scan's step editor — reorder, remove and adjust a macro's steps without opening its JSON. Only the
// person's choices change; element references and everything else in a step are kept as they are.

/** What a person may change on a step, and how each value is checked. */
const EDITABLE = {
	timeout: (value) => Number.isFinite(Number(value)) && Number(value) > 0 && Number(value) <= 120 ? Number(value) : undefined,
	optional: (value) => (typeof value === "boolean" ? value : undefined),
	text: (value) => (typeof value === "string" ? value : undefined),
	seconds: (value) => Number.isFinite(Number(value)) && Number(value) >= 0 && Number(value) <= 120 ? Number(value) : undefined,
	name: (value) => (typeof value === "string" && value.trim() ? value.trim() : undefined),
};

/** Which fields the editor offers for a step. */
export function editableFields(step) {
	switch (step.do) {
		case "tap":
		case "waitFor":
		case "alertTap":
			return ["timeout", "optional"];
		case "type":
			return ["text"];
		case "wait":
			return ["seconds"];
		case "screenshot":
			return ["name"];
		default:
			return [];
	}
}

/**
 * `order`: step ids in their new order — a step left out is removed. `changes`: `{stepId: {field: value}}`, only
 * the fields `editableFields` allows. Returns the new macro; throws on an unknown id or a bad value.
 */
export function applyStepEdits(macro, { order, changes = {} }) {
	const byId = new Map((macro.steps ?? []).map((step) => [step.id, step]));
	if (!Array.isArray(order) || order.length === 0) throw new Error("a macro needs at least one step");
	if (new Set(order).size !== order.length) throw new Error("a step is listed twice");
	const unknown = [...order, ...Object.keys(changes)].filter((id) => !byId.has(id));
	if (unknown.length) throw new Error(`no step ${unknown[0]} in this macro`);
	const steps = order.map((id) => {
		const step = { ...byId.get(id) };
		for (const [field, value] of Object.entries(changes[id] ?? {})) {
			if (!editableFields(step).includes(field)) throw new Error(`“${field}” can't be changed on a ${step.do} step`);
			const checked = EDITABLE[field](value);
			if (checked === undefined) throw new Error(`“${value}” isn't a valid ${field}`);
			step[field] = checked;
		}
		return step;
	});
	return { ...macro, steps, editedAt: new Date().toISOString() };
}

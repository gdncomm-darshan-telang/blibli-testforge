import { randomUUID } from "node:crypto";
/** `URLError.timedOut`. The session file stores the raw value, not the case. */
const URL_ERROR_TIMED_OUT = -1001;
const JSON_HEADERS = { "Content-Type": "application/json" };
/**
 * The failure kinds a step can name, kept identical to `write_mock.py`'s
 * `FAILURES` — the two write the same file and a code the app does not
 * recognise surfaces as a generic error with no clue which tool wrote it.
 */
export const FAILURES = {
    offline: { errorCode: -1009, label: "offline" },
    timedOut: { errorCode: URL_ERROR_TIMED_OUT, label: "timed out" },
    connectionLost: { errorCode: -1005, label: "connection lost" },
    cannotFindHost: { errorCode: -1003, label: "DNS failure" },
    secureConnectionFailed: { errorCode: -1200, label: "TLS failure" },
};
/**
 * One step of a scripted variant, in the shape Swift's synthesised enum
 * `Codable` expects: the case name, then `_0` for its associated value. `hang`
 * carries nothing, so it encodes as an empty object rather than being omitted.
 */
export function step(spec) {
    if (spec.hang)
        return { hang: {} };
    if (spec.fail) {
        const failure = FAILURES[spec.fail];
        return fail(failure.errorCode, failure.label, spec.delay ?? 0);
    }
    const body = spec.bodyBytes ?? Buffer.from(spec.body ?? "", "utf8");
    return respond(body, spec.statusCode ?? 200, spec.headers ?? JSON_HEADERS, spec.delay ?? 0);
}
/** A variant that answers differently on each successive hit. */
export function scriptedVariant(name, steps, exhaustion) {
    return { id: newID(), name, steps, exhaustion };
}
/** One line per step, for a tool that has to show what it just wrote. */
export function describeStep(spec, index) {
    if (spec.hang)
        return `  ${index + 1}. never answers`;
    if (spec.fail)
        return `  ${index + 1}. ${FAILURES[spec.fail].label}${spec.delay ? ` after ${spec.delay}s` : ""}`;
    const size = (spec.bodyBytes ?? Buffer.from(spec.body ?? "", "utf8")).length;
    return `  ${index + 1}. ${spec.statusCode ?? 200} · ${size}B${spec.delay ? ` · ${spec.delay}s delay` : ""}`;
}
export function newID() {
    return randomUUID().toUpperCase();
}
/**
 * One `MockOutcome.respond` step, in the shape Swift's synthesised `Codable`
 * writes it: the case name, then `_0` for its associated value.
 */
function respond(body, statusCode, headers, delay = 0) {
    const data = typeof body === "string" ? Buffer.from(body, "utf8") : body;
    return { respond: { _0: { body: data.toString("base64"), delay, headers, statusCode } } };
}
function fail(errorCode, label, delay = 0) {
    return { fail: { _0: { errorCode, label, delay } } };
}
export function variant(name, steps) {
    return { id: newID(), name, steps, exhaustion: "repeatLast" };
}
/**
 * `loaded`, `empty`, `500`, `slow`, `timeout` — the port of `CapturedVariants`.
 *
 * Kept byte-compatible with the Swift side on purpose: a rule written from here
 * and one captured in the overlay have to be the same thing, or a pack exported
 * after a host-side capture would not survive the round trip.
 */
export function standardSet(body, statusCode = 200, headers = JSON_HEADERS, slowDelay = 3) {
    const captured = body ?? Buffer.alloc(0);
    return [
        variant("loaded", [respond(captured, statusCode, headers)]),
        variant("empty", [respond(emptied(captured), 200, headers)]),
        variant("500", [respond(failed(captured), 500, headers)]),
        variant("slow", [respond(captured, statusCode, headers, slowDelay)]),
        variant("timeout", [fail(URL_ERROR_TIMED_OUT, "timed out")]),
    ];
}
export function ruleFor(endpointKey, variants) {
    return {
        id: newID(),
        endpointKey,
        match: { query: {}, headers: {}, bodyContains: null },
        variants,
        activeVariantID: variants[0]?.id ?? newID(),
        isEnabled: false,
    };
}
/**
 * The captured body with its containers emptied and its envelope intact.
 *
 * A bare `{}` is a different response, not an empty one — the app fails to
 * decode it and shows the error state, so the empty state never renders and the
 * variant proves nothing.
 */
export function emptied(body) {
    try {
        return Buffer.from(JSON.stringify(hollow(JSON.parse(body.toString("utf8")))), "utf8");
    }
    catch {
        return Buffer.from("{}", "utf8");
    }
}
/** Rewrites the app's own envelope rather than inventing an error shape it
 *  does not parse. */
export function failed(body, statusCode = 500) {
    let parsed;
    try {
        parsed = JSON.parse(body.toString("utf8"));
    }
    catch {
        return Buffer.from(`{"error":"internal server error"}`, "utf8");
    }
    if (parsed === null || typeof parsed !== "object" || Array.isArray(parsed)) {
        return Buffer.from(`{"error":"internal server error"}`, "utf8");
    }
    const object = { ...parsed };
    for (const key of Object.keys(object)) {
        switch (key.toLowerCase()) {
            case "code":
                object[key] = statusCode;
                break;
            case "status":
                object[key] = "INTERNAL_SERVER_ERROR";
                break;
            case "data":
            case "value":
            case "result":
            case "payload":
                object[key] = null;
                break;
            default:
                break;
        }
    }
    if (object.errorCode === undefined && object.code !== undefined)
        object.errorCode = "SYSTEM_ERROR";
    return Buffer.from(JSON.stringify(object), "utf8");
}
function hollow(value) {
    if (Array.isArray(value))
        return [];
    if (value === null || typeof value !== "object")
        return value;
    const result = {};
    for (const [key, nested] of Object.entries(value)) {
        result[key] = hollow(nested);
    }
    return result;
}

// Shared resolver for scripts that ship inside the test-flow-recorder plugin install (harness.py,
// macro_cli.py, ...). The install path is machine-specific, so every caller can override with its
// own env var; this just centralizes the fallback glob so it is only written once.
import { existsSync, globSync } from "node:fs";
import { homedir } from "node:os";

const cache = new Map();

export function resolvePluginScript(envVar, scriptName) {
	if (cache.has(envVar)) return cache.get(envVar);

	const explicit = process.env[envVar];
	if (explicit && existsSync(explicit)) {
		cache.set(envVar, explicit);
		return explicit;
	}

	// Bounded depth on purpose: a recursive `~/Projects/**` walk descends into every node_modules and
	// DerivedData and took seconds, stalling the first Load / Ensure click.
	const tail = `skills/test-flow-recorder/scripts/${scriptName}`;
	const home = homedir();
	const patterns = [
		`${home}/Projects/blibli-testforge/plugin/${tail}`,
		`${home}/Projects/*/blibli-testforge/plugin/${tail}`,
		`${home}/Projects/*/*/blibli-testforge/plugin/${tail}`,
		`${home}/.claude/plugins/**/${tail}`,
	];
	for (const pattern of patterns) {
		const matches = globSync(pattern);
		if (matches.length > 0) {
			cache.set(envVar, matches[0]);
			return matches[0];
		}
	}
	cache.set(envVar, null);
	return null;
}

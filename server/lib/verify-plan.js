// F6 (D-196): the developer face of the TestForge. A diff (a branch against its base, a commit range, or the working
// tree) picks the test cases whose recordings cover the changed app code, so they replay without Claude before a PR.
import { coverageOf, isAppCode, SHARED_INPUTS } from "./staleness.js";
import { caseLinks } from "./macro-v2.js";

const isUnder = (file, folder) => file === folder || file.startsWith(folder.endsWith("/") ? folder : `${folder}/`);

/**
 * `changed`: repo-relative files. `macros`: v2 macros (path, covers, links). `caseIds`: the loaded document's ids,
 * so only cases a person can see are proposed. Shared inputs (pods, packages) pick every recorded case.
 */
export function affectedCases({ changed, macros, caseIds = null }) {
	const appFiles = [...new Set(changed.filter(isAppCode))].sort();
	const isShared = appFiles.some((file) => SHARED_INPUTS.includes(file));
	const known = caseIds ? new Set(caseIds.map((id) => String(id).toUpperCase())) : null;
	const byCase = new Map();
	const covered = new Set();
	let unknownCoverage = 0;
	for (const macro of macros) {
		const covers = coverageOf(macro);
		if (!covers) {
			unknownCoverage++;
			continue;
		}
		const hits = isShared ? appFiles : appFiles.filter((file) => covers.some((folder) => isUnder(file, folder)));
		hits.forEach((file) => covered.add(file));
		if (!hits.length) continue;
		for (const caseId of caseLinks(macro)) {
			if (known && !known.has(caseId)) continue;
			if (!byCase.has(caseId)) byCase.set(caseId, { caseId, macroId: macro.id, macroName: macro.name, files: hits.slice(0, 20) });
		}
	}
	const cases = [...byCase.values()].sort((first, second) => first.caseId.localeCompare(second.caseId, undefined, { numeric: true }));
	return {
		changedAppFiles: appFiles,
		cases,
		uncoveredFiles: appFiles.filter((file) => !covered.has(file)),
		isSharedChange: isShared,
		unknownCoverage,
	};
}

/** git arguments for each way of naming a diff; `range` "a..b", or `base` (branch point to HEAD) plus local edits. */
export function diffCommands({ range, base = "develop", isIncludingLocal = true }) {
	if (range) return [["diff", "--name-only", range]];
	const commands = [["diff", "--name-only", `${base}...HEAD`]];
	if (isIncludingLocal) commands.push(["diff", "--name-only", "HEAD"], ["ls-files", "--others", "--exclude-standard"]);
	return commands;
}

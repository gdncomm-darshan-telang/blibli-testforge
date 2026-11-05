# Contributing

## Branching strategy: trunk plus short-lived branches

`main` is the only long-lived branch. It is always installable: the plugin marketplace and `setup.sh` point at it, so a broken `main` breaks every developer's TestForge.

| Branch | Pattern | Rule |
|---|---|---|
| Trunk | `main` | Never push directly. Change it only by PR. |
| Work | `<firstname>/<type>/<topic>` | Branch from `main`, keep it under a few days, delete after merge. |
| Hotfix on an old release | `release/<major>.<minor>` | Only when a shipped tag needs a fix and `main` has moved on. Branch from the tag, fix, tag `v<major>.<minor>.<patch+1>`, then port the fix to `main`. |

`<type>` is one of `feature`, `fix`, `chore`, `docs`, `refactor`, `test`. Examples: `darshan/feature/setup-script`, `asha/fix/replay-timeout`.

### Flow

1. `git switch main && git pull --ff-only`
2. `git switch -c <firstname>/<type>/<topic>`
3. Commit small, push, open a PR into `main`.
4. One approving review (the code owner for the area, see `.github/CODEOWNERS`), CI green when CI exists.
5. **Squash merge**, delete the branch. The squash title is the commit message on `main`.

Rebase your branch on `main` before merging if it is behind. Do not merge `main` into a work branch repeatedly; rebase instead.

## Commits and PR titles

`[TestForge] <summary in the imperative>`, optionally with the area: `[TestForge] Mac app: add Free space row`. Keep the summary under about 70 characters; explain why in the body when it is not obvious.

A non-obvious design choice gets a new `D-NNN` entry in `docs/decision.md` in the same PR (append, never rewrite old entries).

## Releases

Semantic versions, tagged on `main`: `v<major>.<minor>.<patch>`.

- **Patch**: fixes only.
- **Minor**: new features, backward compatible with existing recordings and state.
- **Major**: breaking change to recordings, `~/.testforge` state or the plugin contract. Ship a migration note.

Releasing is: bump the plugin and app versions, update the changelog, merge, tag, and push the tag.

## Enforcement

The private repo plan does not support GitHub branch protection or rulesets, so the rules above are not enforced by the server. Until that changes:

- Enable the tracked hook once per clone: `git config core.hooksPath .githooks`. It refuses a push to `main` (override only for the initial bootstrap with `ALLOW_MAIN_PUSH=1`).
- Reviewers: do not merge a PR that targets anything but `main`, has failing checks, or is not squashed.

If the repo moves to a plan with branch protection, require: PR before merge, 1 approval, code-owner review, linear history (squash only), no force-push, no deletion of `main`.

## Secrets

Do not commit credentials, `.env*`, `.netrc`, `*.p12`, Keychain exports or recorded mocks holding real tokens. If one is committed, rotate it first, then remove it from history.

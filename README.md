# TestForge

A native macOS app and local server that lets QA and developers test the Blibli iOS app without writing code.

- **Replay** recorded test cases on the simulator, with no Claude tokens spent.
- **Mock** network responses live (NetworkLens) and inspect traces.
- **Run with Claude**: a Claude Code plugin drives the XCUITest runner for first runs and failures, and records macros so later replays are free.
- **Prove it**: screenshots, video and a report per Test Batch.
- **Measure** UI spacing and layers straight from the Simulator.
- **Verify** a branch: finds the recorded cases that cover the files you changed and replays them before you raise a PR.

> **Status:** pre-release. Plugin, Mac app and server are all in this repo; run `./setup.sh` to get going. See [CHANGELOG.md](CHANGELOG.md).

## Layout

| Path | What |
|---|---|
| `plugin/` | `test-flow-recorder` Claude Code plugin (this repo is also its marketplace) |
| `mac-app/` | Native SwiftUI Mac app (Swift package, `make-app.sh` builds and signs it) |
| `server/` | Local Node server the app and plugin talk to (port 4545) |
| `docs/` | Map of the documents (the documents themselves sit in `server/docs/`) |
| `setup.sh` | One-command setup for a new machine |

## Requirements

macOS with Xcode and the iOS Simulator, Node.js, ffmpeg, and Claude Code. Access to the Blibli iOS repo (the app under test) and its private Swift packages. `./setup.sh --check` tells you what is missing.

## Getting started

```bash
./setup.sh     # check tools, install server deps, build the Mac app
```

Then follow the two next steps it prints: open the app, add the plugin.

To rebuild the app later, double-click `build-app.command` in Finder (it runs `mac-app/scripts/make-app.sh`).

## Working in this repo

Branches, commits, PRs and releases: see [CONTRIBUTING.md](CONTRIBUTING.md). Short version: `master` is always installable, work happens on `<name>/<type>/<topic>` branches, everything reaches `master` through a squash-merged PR.

## Secrets

Never commit credentials, `.env*` files, `.netrc`, signing certificates (`*.p12`), Keychain exports, or captured network mocks that contain real tokens. Test logins live in the macOS Keychain.

# TestForge

A native macOS app and local server that lets QA and developers test the Blibli iOS app without writing code.

- **Replay** recorded test cases on the simulator, with no Claude tokens spent.
- **Mock** network responses live (NetworkLens) and inspect traces.
- **Run with Claude**: a Claude Code plugin drives the XCUITest runner for first runs and failures, and records macros so later replays are free.
- **Prove it**: screenshots, video and a report per Test Batch.
- **Measure** UI spacing and layers straight from the Simulator.
- **Verify** a branch: finds the recorded cases that cover the files you changed and replays them before you raise a PR.

> **Status:** repository scaffolding only. Code is moved in from `BlibliIOSApp-POC` (branch `darshan/innovation/qa-mocker`) in follow-up PRs.

## Planned layout

| Path | What |
|---|---|
| `plugin/` | `qa-flow-recorder` Claude Code plugin (this repo is also its marketplace) |
| `mac-app/` | Native SwiftUI Mac app (Swift package, `make-app.sh` builds and signs it) |
| `server/` | Local Node server the app and plugin talk to (port 4545) |
| `docs/` | Design, decisions, tutorials |
| `setup.sh` | One-command setup for a new machine |

## Requirements

macOS with Xcode and the iOS Simulator, Node.js, ffmpeg, and Claude Code. Access to the Blibli iOS repo (the app under test) and its private Swift packages. Details land with `setup.sh`.

## Working in this repo

Branches, commits, PRs and releases: see [CONTRIBUTING.md](CONTRIBUTING.md). Short version: `main` is always installable, work happens on `<name>/<type>/<topic>` branches, everything reaches `main` through a squash-merged PR.

## Secrets

Never commit credentials, `.env*` files, `.netrc`, signing certificates (`*.p12`), Keychain exports, or captured network mocks that contain real tokens. Test logins live in the macOS Keychain.

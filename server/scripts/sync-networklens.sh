#!/bin/bash
# Re-copies the NetworkLens MCP build into the dashboard (D-050). The files under lib/ listed below
# are never hand-edited: change them upstream in NetworkInterceptor
# (NetworkLens/Tools/networklens-mcp), build there, then run this.
#
#   scripts/sync-networklens.sh <path to a NetworkInterceptor checkout or worktree>
set -euo pipefail

CHECKOUT="${1:?usage: sync-networklens.sh <NetworkInterceptor checkout>}"
MCP="$CHECKOUT/NetworkLens/Tools/networklens-mcp"
DASHBOARD="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MIRROR="$DASHBOARD/../networklens-mcp/dist"

(cd "$MCP" && npm run build --silent)

for name in session variants trace container redact control android; do
	cp "$MCP/dist/$name.js" "$DASHBOARD/lib/$name.js"
done
# The dashboard keeps the queue as control-queue.js (decision.md, first entry): the only rename, applied here, never by hand.
cp "$MCP/dist/queue.js" "$DASHBOARD/lib/control-queue.js"
sed -i '' 's|from "./queue.js"|from "./control-queue.js"|' "$DASHBOARD/lib/control.js"

mkdir -p "$MIRROR"
cp "$MCP"/dist/*.js "$MIRROR/"

REVISION="$(git -C "$CHECKOUT" rev-parse --short HEAD)"
BRANCH="$(git -C "$CHECKOUT" branch --show-current)"
printf '%s @ %s\n' "$BRANCH" "$REVISION" > "$DASHBOARD/lib/NETWORKLENS_REVISION"
echo "synced networklens-mcp from $BRANCH @ $REVISION"

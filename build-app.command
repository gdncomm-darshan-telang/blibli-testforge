#!/bin/bash
# Double-click in Finder to build the TestForge Mac app (mac-app/build/TestForge.app).
# Runs from wherever this checkout lives: paths are relative to this file.
cd "$(dirname "$0")/mac-app" || exit 1
./scripts/make-app.sh
status=$?
echo
if [ "$status" -eq 0 ]; then
	echo "Built: $(pwd)/build/TestForge.app"
else
	echo "Build failed (exit $status)."
fi
read -n 1 -s -r -p "Press any key to close."
exit "$status"

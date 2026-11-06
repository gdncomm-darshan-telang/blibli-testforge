#!/bin/bash
# Double-click in Finder to build the TestForge Mac app (mac-app/build/TestForge.app) and open it.
# Runs from wherever this checkout lives: paths are relative to this file.
cd "$(dirname "$0")/mac-app" || exit 1
./scripts/make-app.sh
status=$?
echo
if [ "$status" -eq 0 ]; then
	echo "Built: $(pwd)/build/TestForge.app"
	if pgrep -f "build/TestForge.app/Contents/MacOS/TestForge" >/dev/null; then
		echo "TestForge is already running: quit it, then open the app again to use this build."
	fi
	open "$(pwd)/build/TestForge.app"
else
	echo "Build failed (exit $status)."
fi
read -n 1 -s -r -p "Press any key to close."
exit "$status"

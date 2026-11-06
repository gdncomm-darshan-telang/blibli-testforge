#!/bin/bash
# Double-click in Finder to build the TestForge Mac app (mac-app/build/TestForge.app) and open it.
# Runs from wherever this checkout lives: paths are relative to this file.
cd "$(dirname "$0")/mac-app" || exit 1
# Swift caches absolute paths: a moved checkout needs a fresh .build.
if [ -f .build/.checkout-path ] && [ "$(cat .build/.checkout-path)" != "$(pwd)" ]; then
	echo "Checkout moved: clearing the old build cache."
	rm -rf .build
fi
./scripts/make-app.sh
status=$?
if [ "$status" -eq 0 ] && [ -d .build ]; then
	pwd > .build/.checkout-path
fi
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

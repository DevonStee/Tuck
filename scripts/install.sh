#!/bin/bash
# Builds Tuck and installs it to /Applications, replacing any running copy.
set -euo pipefail

cd "$(dirname "$0")/.."
scripts/build-app.sh
pkill -x Tuck || true
rm -rf /Applications/Tuck.app
cp -R build/Tuck.app /Applications/Tuck.app
open /Applications/Tuck.app
echo "Installed /Applications/Tuck.app"

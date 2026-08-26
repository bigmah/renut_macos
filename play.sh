#!/usr/bin/env bash
# Launch Banjo-Kazooie: Nuts & Bolts on macOS (Apple Silicon).
# Must run from the build dir: assets/ and renut.toml are symlinked there, and
# the Vulkan/MoltenVK loader is staged in ./vulkan.
set -euo pipefail
BUILD="$(cd "$(dirname "$0")" && pwd)/tools/reNut/out/build/mac-arm64-release"
[ -x "$BUILD/renut" ] || { echo "Not built yet. See README.md (Build)." >&2; exit 1; }
cd "$BUILD"
exec ./renut "$@"

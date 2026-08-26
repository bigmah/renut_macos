#!/usr/bin/env bash
# Launch Banjo-Kazooie: Nuts & Bolts (reNut) on macOS ARM64.
# The binary must run from its build dir: assets/ and renut.toml are symlinked
# there, and the Vulkan/MoltenVK loader is staged in ./vulkan.
set -euo pipefail
BUILD="$(dirname "$0")/tools/reNut/out/build/mac-arm64-release"
cd "$BUILD"
exec ./renut "$@"

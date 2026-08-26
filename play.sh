#!/usr/bin/env bash
# Launch Banjo-Kazooie: Nuts & Bolts on macOS (Apple Silicon).
# Must run from the build dir: assets/ and renut.toml are symlinked there, and
# the Vulkan/MoltenVK loader is staged in ./vulkan.
set -euo pipefail
BUILD="$(cd "$(dirname "$0")" && pwd)/tools/reNut/out/build/mac-arm64-release"
[ -x "$BUILD/renut" ] || { echo "Not built yet. See README.md (Build)." >&2; exit 1; }
cd "$BUILD"

# MoltenVK reports the same benign primitive-restart portability warning for
# every affected graphics pipeline. Nuts & Bolts creates thousands of pipeline
# variants, so leaving MoltenVK's default warning level enabled can turn stderr
# formatting and terminal I/O into a measurable launch/runtime cost. Preserve a
# caller override for debugging, but keep the normal play path error-only.
export MVK_CONFIG_LOG_LEVEL="${MVK_CONFIG_LOG_LEVEL:-1}"

exec ./renut "$@"

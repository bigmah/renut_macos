#!/usr/bin/env bash
# Rebuild reNut after editing sources. Codegen re-runs automatically when the
# XEX or any config/*.toml changes (wired via the codegen.d depfile).
set -euo pipefail
cd "$(dirname "$0")/tools/reNut"
cmake --build out/build/mac-arm64-release --parallel

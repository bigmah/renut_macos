#!/usr/bin/env bash
# Rebuild after editing sources. Codegen re-runs on its own when the XEX or any
# config/*.toml changes, wired through its depfile.
set -euo pipefail
cd "$(cd "$(dirname "$0")" && pwd)/tools/reNut"
cmake --build out/build/mac-arm64-release --parallel

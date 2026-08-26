# Banjo-Kazooie: Nuts & Bolts on macOS (Apple Silicon)

Static recompilation of the Xbox 360 game to a native arm64 macOS binary, using
[rexglue-sdk](https://github.com/rexglue/rexglue-sdk) and
[reNut](https://github.com/masterspike52/reNut).

Verified booting on an M4 Pro (macOS 26.6): MoltenVK creates a `VkDevice` on the
Apple M4 Pro and a 2560x1440 swapchain on a `CAMetalLayer`.

## Requirements

You must supply your own disc image of the **US (NTSC-U)** release. Nothing in
this repo contains game data, and none of it is redistributable.

Verify a candidate image before building:

| Field | Expected |
| --- | --- |
| Format | XGD2 (`MICROSOFT*XBOX*MEDIA` at `0xFD90000 + 0x10000`) |
| Title ID | `4D5307ED` |
| Region | `0x000000FF` (NTSC-U) |

reNut's README notes the title update is not used; the recomp runs off the
disc's `default.xex`.

## Layout

`tools/` is gitignored. It holds three independent clones, two of which carry
local work on a branch:

| Path | Branch | Notes |
| --- | --- | --- |
| `tools/rexglue-sdk` | `macos-arm64-fixes` | Recompiler and runtime. Pinned to `c94f5eb`. |
| `tools/reNut` | `macos-arm64-port` | The game project and the macOS port. |
| `tools/extract-xiso` | - | Builds from source; not in Homebrew. |

**Pin the SDK.** macOS support landed only after v0.9.0, and the version that
has it - 0.10.0 - is not tagged, so there is no release to ask for by name.
`c94f5eb` is the verified commit. The SDK is also explicit that it is early and
expects breaking changes: the 0.8.0 API this project was written against no
longer exists.

`tools/reNut/assets/` (extracted disc) and `tools/reNut/generated/` (C++ emitted
from the guest XEX) are both gitignored as game-derived content.

Budget roughly **15 GB** free: 7.3 GB ISO, 6.1 GB extracted, ~220 MB generated
C++, and ~1 GB of build output. The SDK's own submodules add ~400 MB.

## Scripts

- `./play.sh` - launch. Runs from the build directory, where `assets/`,
  `renut.toml` and the staged `vulkan/` loader live.
- `./rebuild.sh` - rebuild after edits. Codegen re-runs automatically when the
  XEX or any `config/*.toml` changes, via its depfile.

## Building from scratch

```sh
brew install cmake ninja vulkan-loader molten-vk

# The SDK, pinned. Submodules are fetched after checkout, not during clone.
git clone https://github.com/rexglue/rexglue-sdk.git tools/rexglue-sdk
git -C tools/rexglue-sdk checkout c94f5eb
git -C tools/rexglue-sdk submodule update --init --recursive

git clone https://github.com/masterspike52/reNut.git tools/reNut
git clone https://github.com/XboxDev/extract-xiso.git tools/extract-xiso

# extract-xiso handles the XGD2 partition offset correctly
cmake -S tools/extract-xiso -B tools/extract-xiso/build -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build tools/extract-xiso/build
./tools/extract-xiso/build/extract-xiso -d tools/reNut/assets your_game.iso

# Build the codegen tool, then recompile the XEX (~10s)
cmake --preset mac-arm64 -S tools/rexglue-sdk \
  -DCMAKE_C_COMPILER=/usr/bin/clang -DCMAKE_CXX_COMPILER=/usr/bin/clang++ \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=13.3
cmake --build tools/rexglue-sdk/out/build/mac-arm64 --config Release --target rexglue --parallel
(cd tools/reNut && ../rexglue-sdk/out/mac-arm64/Release/rexglue codegen renut_manifest.toml)

# Build the game. reNut finds the SDK as a sibling automatically; pass
# -DREXSDK_DIR=<path> if it lives somewhere else.
cmake --preset mac-arm64-release -S tools/reNut
cmake --build tools/reNut/out/build/mac-arm64-release --parallel
```

Those clones are **upstream**, which does not build on macOS as-is: that is
what the two branches under [Local branches](#local-branches) provide. Apply
both before the codegen and build steps.

First launch shows a path-setup wizard. To skip it, write `renut.cfg` next to
the binary with `game_data_root` and `user_data_root` set.

## Local branches

Neither branch is hosted here - both live in their own clone under `tools/`,
as commits against their respective upstreams, so they stay submittable.

### `rexglue-sdk` @ `macos-arm64-fixes`

Three independent SDK bugs, each reproducible without this project:

| Commit | Fix |
| --- | --- |
| `070d7c0` | `REXGLUE_ROOT` was set with a directory-scoped `set()`, so it is empty in the scope where `rexglue_configure_target()` runs. The macOS MoltenVK ICD staging then resolves the absolute `/cmake/MoltenVK_icd.json` and the build fails. Hits **any** consumer using `add_subdirectory` on macOS. |
| `e346c4e` | `rexglue_configure_target()` injects `rex_app.cpp` but links only `rex::runtime`, so consumers hit `'imgui.h' file not found` for a dependency they never asked for. |
| `d38ac48` | `setcsr()` passed a `u32` under an `"r"` constraint into `msr fpcr, %0`, leaving the upper half of the X register undefined. Affects **every** arm64 target, Linux arm64 included. |

Verified by stripping reNut's workarounds and building against these fixes
alone: `REXGLUE_ROOT` resolved, the ICD staged, and the warning went to zero.

### `reNut` @ `macos-arm64-port`

Six commits, ordered so the platform-agnostic bug lands first:

| Commit | Change |
| --- | --- |
| `3b841cd` | Build `cvar_menu.cpp` and `FPS.cpp`. Codegen emits calls into both, so the link fails on **every** platform without them. |
| `5e7f5f4` | Use the SDK's `GetExecutableFolder()` in the path store. |
| `2717e7d` | Replace the Win32 COM folder picker with SDL3's. |
| `ee06934` | Port `frameHooks.cpp` off Win32. |
| `7ccb62e` | Migrate to the rexglue-sdk 0.10 API. |
| `895f483` | Add macOS ARM64 build support. |

`895f483` keeps two workarounds that duplicate the SDK fixes above - setting
`REXGLUE_ROOT` locally and linking `rex::ui`. That is deliberate: the pin
`c94f5eb` is unpatched upstream, so reNut has to build against an SDK that
still has both bugs. Drop them once the SDK fixes land.

## Licensing

**rexglue-sdk** is BSD 3-Clause (Tom Clay), with portions derived from Xenia.
Contributing back is straightforward.

**reNut has no LICENSE file** and no license statement in its README, so the
default applies: all rights reserved. Forking on GitHub is covered by GitHub's
terms, but relicensing it, redistributing it off-platform, or branding a
separate project on top of it is not. Ask the maintainer to add a license
before building anything public on it; contributing changes back by PR is fine
either way.

Separately, and regardless of either license: **never commit or ship game
data.** The disc image, the extracted disc and the C++ codegen emits from the
XEX are all excluded here, and that is what keeps a project like this viable.

## Known issues

- MoltenVK logs `Metal does not support disabling primitive restart` once per
  pipeline creation. Benign, but it produced a 5.2 MB log in one run, so keep
  `log_level = "off"` in `renut.toml` outside of debugging. Geometry glitches
  would be the first thing to attribute to it.
- Gameplay beyond boot - audio, controller input, sustained framerate - is not
  yet verified.

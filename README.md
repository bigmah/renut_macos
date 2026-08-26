# Banjo-Kazooie: Nuts & Bolts on macOS (Apple Silicon)

Build scaffolding for running [Banjo-Kazooie: Nuts &
Bolts](https://en.wikipedia.org/wiki/Banjo-Kazooie:_Nuts_%26_Bolts) as a native
arm64 macOS binary, statically recompiled from Xbox 360 PowerPC.

**This repo contains no third-party code.** It is a thin consumer: the game
project and the recompiler are pulled in as submodules from forks, so their
code stays in their own repositories with their own history.

| Component | Consumed from | Upstream |
| --- | --- | --- |
| reNut | [bigmah/reNut](https://github.com/bigmah/reNut) `macos-arm64` | [masterspike52/reNut](https://github.com/masterspike52/reNut) |
| ReXGlue SDK | [bigmah/rexglue-sdk](https://github.com/bigmah/rexglue-sdk) `macos-arm64-fixes` | [rexglue/rexglue-sdk](https://github.com/rexglue/rexglue-sdk) |

All the hard work - the recompiler, the runtime, the game-specific hooks - is
theirs. What lives here is the macOS platform work and the build glue.

Verified on an M4 Pro (macOS 26.6): MoltenVK creates a `VkDevice` on the Apple
GPU and a 2560x1440 swapchain on a `CAMetalLayer`.

> **No game data is included, and none is redistributable.** You supply your own
> disc image. The recompiler transforms files you already own; it ships none of
> them.

## Requirements

- Apple Silicon Mac, macOS 13.3+
- Your own disc image of the **US (NTSC-U)** release
- ~15 GB free: 7.3 GB ISO, 6.1 GB extracted, ~220 MB generated C++, ~1 GB build

Worth verifying an image before building:

| Field | Expected |
| --- | --- |
| Format | XGD2 (`MICROSOFT*XBOX*MEDIA` at `0xFD90000 + 0x10000`) |
| Title ID | `4D5307ED` |
| Region | `0x000000FF` (NTSC-U) |

The title update is not used; the recomp runs off the disc's `default.xex`.

## Build

```sh
brew install cmake ninja vulkan-loader molten-vk

git clone --recurse-submodules https://github.com/bigmah/renut_macos.git
cd renut_macos
```

`--recurse-submodules` matters, and it nests two levels: this repo pulls reNut,
which pulls the SDK. If you cloned without it, run `git submodule update --init
--recursive`.

Extract your disc into `tools/reNut/assets/` (gitignored). `extract-xiso`
handles the XGD2 partition offset and is not in Homebrew, so build it:

```sh
git clone https://github.com/XboxDev/extract-xiso.git /tmp/extract-xiso
cmake -S /tmp/extract-xiso -B /tmp/extract-xiso/build -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build /tmp/extract-xiso/build
/tmp/extract-xiso/build/extract-xiso -d tools/reNut/assets /path/to/your.iso
```

Build the codegen tool from the pinned SDK, then recompile the XEX (~10s):

```sh
cd tools/reNut
cmake --preset mac-arm64 -S thirdparty/rexglue-sdk \
  -DCMAKE_C_COMPILER=/usr/bin/clang -DCMAKE_CXX_COMPILER=/usr/bin/clang++ \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=13.3
cmake --build thirdparty/rexglue-sdk/out/build/mac-arm64 --config Release --target rexglue --parallel
thirdparty/rexglue-sdk/out/mac-arm64/Release/rexglue codegen renut_manifest.toml
```

Then the game itself (~3 min cold, on an M4 Pro):

```sh
cmake --preset mac-arm64-release
cmake --build out/build/mac-arm64-release --parallel
```

## Run

From the repository root:

```sh
./play.sh      # launch
./rebuild.sh   # rebuild after edits; codegen re-runs when inputs change
```

First launch shows a path-setup wizard. To skip it, drop a `renut.cfg` beside
the binary in `tools/reNut/out/build/mac-arm64-release/`:

```ini
game_data_root   = "/absolute/path/to/renut_macos/tools/reNut/assets"
user_data_root   = "/Users/you/Library/Application Support/renut"
update_data_root = ""
```

Runtime settings live in `tools/reNut/renut.toml`. Keep `log_level = "off"`
outside of debugging - see Known issues.

## Why forks rather than upstream

Neither upstream builds on macOS as-is.

**reNut** needed the platform work: the Win32 folder picker replaced with
SDL3's, the frame limiter moved off a Win32 waitable timer, the executable-path
lookup moved to the SDK's own helper, and Discord Rich Presence guarded behind
`__has_include` since that header left the SDK after 0.8.0. Two of the fixes are
not macOS-specific at all - `cvar_menu.cpp` and `FPS.cpp` were not compiled by
any CMakeLists despite codegen emitting calls into them, which fails the link on
every platform.

`macos-arm64-port` on the fork holds that as six commits against upstream reNut,
kept rebasable in case they are useful there. `macos-arm64` is the same work
plus the SDK pin below, and is what this repo consumes.

**The SDK** needed four fixes, all in consumer mode - none of them show up in
the SDK's own builds or CI, because standalone it is the top-level project:

| Fix | Why it matters |
| --- | --- |
| `REXGLUE_ROOT` set with a directory-scoped `set()` | Empty in the scope where `rexglue_configure_target()` runs, so the macOS MoltenVK ICD staging resolves the absolute `/cmake/MoltenVK_icd.json` and the build fails. |
| `rexglue_configure_target()` links only `rex::runtime` | It injects `rex_app.cpp`, which reaches imgui headers, so consumers hit `'imgui.h' file not found` for a dependency they never asked for. |
| `setcsr()` passed a `u32` into `msr fpcr, %0` | The operand is an X register, so the upper half was undefined - unspecified bits written to FPCR. Affects **every** arm64 target, Linux arm64 included. |
| `rex_resolve_version()` read `CMAKE_SOURCE_DIR` | That is the top-level project, so under `add_subdirectory()` it describes the *consumer's* git tags. Any consumer with a `v*` tag ahead of the SDK's floor cannot configure at all. |

The SDK fork is pinned at `1c4a04b` - upstream `c94f5eb` plus those four. A
commit rather than a tag, because `c94f5eb` sits past the `v0.10.0` tag. macOS
support landed only after v0.9.0, and the SDK states plainly that it is early
and expects breaking changes: the 0.8.0 API reNut was written against no longer
exists.

## Known issues

- MoltenVK logs `Metal does not support disabling primitive restart` once per
  pipeline creation. Benign, but it produced a 5.2 MB log in one run, so keep
  `log_level = "off"` outside of debugging. Geometry glitches would be the first
  thing to attribute to it.
- Gameplay beyond boot - audio, controller input, sustained framerate - is not
  yet verified.
- Intel Macs are untested. The presets ship arm64 only rather than claim support
  that was never exercised.

## Licensing

`rexglue-sdk` is BSD 3-Clause, with portions derived from Xenia.

**reNut ships no LICENSE file**, so the default applies: all rights reserved by
its authors. That is why its code is consumed from a GitHub fork rather than
copied into this repository. Nothing here claims any rights over it.

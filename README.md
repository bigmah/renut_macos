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

`tools/` is gitignored. It holds three independent clones:

- `tools/rexglue-sdk` - the recompiler and runtime. Needs the **nightly**;
  releases up to v0.9.0 have no macOS support at all.
- `tools/reNut` - the game project. The macOS port lives on the
  `macos-arm64-port` branch.
- `tools/extract-xiso` - builds from source; not in Homebrew.

`tools/reNut/assets/` (extracted disc) and `tools/reNut/generated/` (C++ emitted
from the guest XEX) are both gitignored as game-derived content.

## Scripts

- `./play.sh` - launch. Runs from the build directory, where `assets/`,
  `renut.toml` and the staged `vulkan/` loader live.
- `./rebuild.sh` - rebuild after edits. Codegen re-runs automatically when the
  XEX or any `config/*.toml` changes, via its depfile.

## Building from scratch

```sh
brew install cmake ninja vulkan-loader molten-vk

git clone --recurse-submodules https://github.com/rexglue/rexglue-sdk.git tools/rexglue-sdk
git clone https://github.com/masterspike52/reNut.git tools/reNut
git clone https://github.com/XboxDev/extract-xiso.git tools/extract-xiso

# extract-xiso handles the XGD2 partition offset correctly
cmake -S tools/extract-xiso -B tools/extract-xiso/build -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build tools/extract-xiso/build
./tools/extract-xiso/build/extract-xiso -d tools/reNut/assets your_game.iso

# Build the codegen tool, then recompile the XEX (~10s)
cmake --preset mac-arm64 -S tools/rexglue-sdk
cmake --build tools/rexglue-sdk/out/build/mac-arm64 --config Release --target rexglue --parallel
(cd tools/reNut && ../rexglue-sdk/out/mac-arm64/Release/rexglue codegen renut_manifest.toml)

# Build the game (apply the macos-arm64-port branch first)
cmake --preset mac-arm64-release -S tools/reNut
cmake --build tools/reNut/out/build/mac-arm64-release --parallel
```

First launch shows a path-setup wizard. To skip it, write `renut.cfg` next to
the binary with `game_data_root` and `user_data_root` set.

## Known issues

- MoltenVK logs `Metal does not support disabling primitive restart` once per
  pipeline creation. Benign, but it produced a 5.2 MB log in one run, so keep
  `log_level = "off"` in `renut.toml` outside of debugging. Geometry glitches
  would be the first thing to attribute to it.
- Gameplay beyond boot - audio, controller input, sustained framerate - is not
  yet verified.

# Hill Climb Racing for PortMaster (experimental)

An ARM64 Linux compatibility-loader port of Fingersoft's original Android
game for R36S-class handhelds. It runs the game's own native library; it is not
an Android emulator and does not reimplement the game.

> Bring your own game. The repository and public release contain no APK,
> extracted game assets, or Fingersoft native libraries. Nothing is downloaded
> automatically.

## Requirements

- A 64-bit ARM PortMaster device with OpenGL ES 2, currently tested on R36S.
- A legally obtained standalone APK matching Hill Climb Racing 1.67.0.
- APK SHA-256:
  `542c25e56ac80768d4a9f74bd77ef463deb4517623df886ee0602315107b150a`

An APK with another hash is rejected. A file renamed by a distributor may show
a different filename; the SHA-256 above and the internal ARM64 library are what
the installer checks.

## Install

1. Download `hillclimbracing.zip` from this project's GitHub Releases page.
2. Copy the ZIP unchanged to PortMaster's `autoinstall` folder:
   - ArkOS / dArkOS: `/roms/tools/PortMaster/autoinstall/`
   - AmberELEC / ROCKNIX / JELOS: `/roms/ports/PortMaster/autoinstall/`
3. Let PortMaster install it, then copy your compatible APK to:
   `ports/hillclimbracing/hcr.apk`
4. Launch **Hill Climb Racing** from the Ports menu.

On first launch the port verifies the APK, extracts its `assets/` and ARM64
`libgame.so`, and applies the version-pinned ArkOS/glibc TLS compatibility fix.
The original APK remains in the folder because the Cocos2d-x asset manager
uses its index while the game is running. First setup needs roughly 250 MB of
free space in addition to the installed port.

If the game returns to the menu, attach both
`HillClimbRacing-bootstrap.log` and `hillclimbracing/log.txt` when reporting an
issue.

## Controls

| Control | Action |
| --- | --- |
| B or R2 | Gas |
| Y or L2 | Brake |
| Right stick or D-pad | Move the yellow menu cursor |
| A or right-stick click (R3) | Touch/click |
| Start | Pause/back |
| X | Boost where available |

**Quitting the game:** open the in-game exit menu, move the cursor to **OK**,
and click **OK twice**. A single click may not close the game on this port.

## What the compatibility layer does

The `hcr` executable supplies the Android/JNI, OpenSL ES, asset, input and
lifecycle calls expected by the game's native Cocos2d-x library. The separate
`hcr-tls-patcher` changes exactly 3,201 version-pinned Android stack-guard reads
to private module storage. Unknown APK/library layouts are refused rather than
patched heuristically.

The online shop, ads, leaderboards, cloud saves and live events are not
available. Saves are local to the port folder.

## Building

Use an AArch64 Linux toolchain targeting glibc 2.29 or older, with SDL2, EGL
and GLES2 development files available in its sysroot:

```sh
./build.sh
python3 tools/package_public.py
```

For PC-side preparation during development only:

```sh
python3 tools/prepare_game.py /path/to/owned.apk
```

## Status

The current build was tested on an R36S and reached the game menu. A QEMU +
Mesa offscreen smoke test also initializes game preferences and save data.
Other PortMaster devices and CFWs still need hardware testing, so the port is
marked experimental.

## Credits and license

Hill Climb Racing is owned by Fingersoft. No game files are licensed or
distributed by this project. The compatibility-loader work is adapted from
HCR_NX by xFlippy and is released under the MIT License; see `LICENSE`.

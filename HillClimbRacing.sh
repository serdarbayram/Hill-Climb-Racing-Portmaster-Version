#!/bin/bash

# Resolve everything relative to this launcher.  On R36S images the ports
# partition may be mounted at /roms, /roms2 or /storage/roms, so relying on
# PORTS_FOLDER can make the script exit before the game log is created.
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" 2>/dev/null && pwd)"
[ -n "$SCRIPT_DIR" ] || SCRIPT_DIR="$(pwd)"

# This log is created before PortMaster's control file is loaded, allowing
# early launcher failures to be diagnosed as well.
BOOT_LOG="$SCRIPT_DIR/HillClimbRacing-bootstrap.log"
exec >"$BOOT_LOG" 2>&1
set -x

echo "Hill Climb Racing launcher started"
date
uname -a
echo "launcher=$0"
echo "script_dir=$SCRIPT_DIR"

GAMEDIR="$SCRIPT_DIR/hillclimbracing"
if [ ! -d "$GAMEDIR" ]; then
  echo "ERROR: Game directory was not found: $GAMEDIR"
  echo "Expected HillClimbRacing.sh and hillclimbracing/ side by side."
  exit 10
fi

# From this point onward, keep the usual game-side log too.
cp "$BOOT_LOG" "$GAMEDIR/log.txt" 2>/dev/null || true
exec >>"$GAMEDIR/log.txt" 2>&1

controlfolder=""
for candidate in \
  "$SCRIPT_DIR/PortMaster" \
  "/opt/system/Tools/PortMaster" \
  "/opt/tools/PortMaster" \
  "/roms/ports/PortMaster" \
  "/roms2/ports/PortMaster" \
  "/storage/roms/ports/PortMaster"
do
  if [ -f "$candidate/control.txt" ]; then
    controlfolder="$candidate"
    break
  fi
done

if [ -n "$controlfolder" ]; then
  echo "PortMaster control folder: $controlfolder"
  source "$controlfolder/control.txt"
  type get_controls >/dev/null 2>&1 && get_controls
  [ -f "$controlfolder/mod_${CFW_NAME}.txt" ] && source "$controlfolder/mod_${CFW_NAME}.txt"
else
  echo "WARNING: PortMaster control.txt was not found; starting directly."
fi

cd "$GAMEDIR" || exit 11
chmod +x ./hcr ./hcr-tls-patcher 2>/dev/null || true

show_error() {
  echo "ERROR: $1"
  if type pm_message >/dev/null 2>&1; then
    pm_message "$1"
  fi
}

prepare_apk() {
  expected="542c25e56ac80768d4a9f74bd77ef463deb4517623df886ee0602315107b150a"
  apk=""
  if [ -f "$GAMEDIR/hcr.apk" ]; then
    apk="$GAMEDIR/hcr.apk"
  else
    for candidate in "$GAMEDIR"/*.apk; do
      if [ -f "$candidate" ]; then
        apk="$candidate"
        break
      fi
    done
  fi

  if [ -z "$apk" ]; then
    show_error "Hill Climb Racing APK bulunamadi. Uyumlu APK dosyasini hillclimbracing klasorune hcr.apk adiyla kopyalayin."
    return 1
  fi
  if ! command -v sha256sum >/dev/null 2>&1; then
    show_error "Bu sistemde sha256sum bulunamadi; APK guvenli bicimde dogrulanamiyor."
    return 1
  fi

  actual=$(sha256sum "$apk" | awk '{print $1}')
  if [ "$actual" != "$expected" ]; then
    show_error "Uyumsuz APK. Gereken surum: Fingersoft Hill Climb Racing 1.67.0, SHA-256: $expected"
    return 1
  fi
  if command -v unzip >/dev/null 2>&1; then
    unzip_cmd="unzip"
  elif command -v busybox >/dev/null 2>&1 && busybox unzip 2>&1 | grep -qi unzip; then
    unzip_cmd="busybox unzip"
  else
    show_error "APK dosyasini acmak icin unzip bulunamadi."
    return 1
  fi
  if [ ! -x "$GAMEDIR/hcr-tls-patcher" ]; then
    show_error "Kurulum araci hcr-tls-patcher eksik. Port paketini yeniden kurun."
    return 1
  fi

  tmp="$GAMEDIR/.install-tmp"
  rm -rf "$tmp"
  mkdir -p "$tmp" || return 1
  echo "Verified APK. Extracting owned game data..."
  if ! $unzip_cmd -q "$apk" 'assets/*' 'lib/arm64-v8a/libgame.so' -d "$tmp"; then
    rm -rf "$tmp"
    show_error "APK dosyalari cikartilamadi. SD kartta yeterli bos alan oldugunu kontrol edin."
    return 1
  fi
  if [ ! -f "$tmp/lib/arm64-v8a/libgame.so" ] || [ ! -d "$tmp/assets" ]; then
    rm -rf "$tmp"
    show_error "APK gerekli ARM64 oyun dosyalarini icermiyor."
    return 1
  fi
  if ! ${HCR_PATCHER_RUNNER:-} "$GAMEDIR/hcr-tls-patcher" "$tmp/lib/arm64-v8a/libgame.so"; then
    rm -rf "$tmp"
    show_error "APK kutuphanesine ArkOS uyumluluk duzeltmesi uygulanamadi."
    return 1
  fi

  rm -rf "$GAMEDIR/assets"
  rm -f "$GAMEDIR/libgame.so"
  mv "$tmp/assets" "$GAMEDIR/assets" || return 1
  mv "$tmp/lib/arm64-v8a/libgame.so" "$GAMEDIR/libgame.so" || return 1
  rm -rf "$tmp"
  if [ "$apk" != "$GAMEDIR/hcr.apk" ]; then
    mv "$apk" "$GAMEDIR/hcr.apk" || return 1
  fi
  touch "$GAMEDIR/.hcr-installed"
  echo "APK setup completed."
}

if [ ! -f "$GAMEDIR/hcr.apk" ] || [ ! -f "$GAMEDIR/libgame.so" ] || [ ! -d "$GAMEDIR/assets" ]; then
  prepare_apk || {
    type pm_finish >/dev/null 2>&1 && pm_finish
    exit 20
  }
fi

if [ -n "$sdl_controllerconfig" ]; then
  export SDL_GAMECONTROLLERCONFIG="$sdl_controllerconfig"
fi

echo "working_dir=$(pwd)"
ls -ld ./hcr ./libgame.so ./hcr.apk ./assets 2>&1 || true

if type pm_platform_helper >/dev/null 2>&1; then
  pm_platform_helper "$GAMEDIR/hcr"
fi

${HCR_GAME_RUNNER:-} ./hcr
result=$?
echo "hcr_exit_code=$result"

type pm_finish >/dev/null 2>&1 && pm_finish
exit "$result"

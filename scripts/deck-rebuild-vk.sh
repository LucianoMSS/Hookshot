#!/usr/bin/env bash
# Rebuild hookshot_vk.so from this fork on a Steam Deck, using the installed Hookshot Builder tools.
#
# Usage (on the Deck):
#   cd ~/src/Hookshot && git pull
#   ./scripts/deck-rebuild-vk.sh ~/Games/Hookshot
#   # then start the game as usual (desktop shortcut or):
#   ~/Games/Hookshot/bin/hookshot
#
# Faster than a full game rebuild: only the Vulkan back end is recompiled (RX_VK_ONLY=1).
set -euo pipefail

GAME="${1:-$HOME/Games/Hookshot}"
FORK="$(cd "$(dirname "$0")/.." && pwd)"
BUILDER_HOME="${HOOKSHOT_BUILDER_HOME:-${XDG_DATA_HOME:-$HOME/.local/share}/hookshot/builder}"
# Prefer newest installed builder version
VERSION_DIR="$(ls -d "$BUILDER_HOME"/versions/v* 2>/dev/null | sort -V | tail -1 || true)"
if [[ -z "${VERSION_DIR}" || ! -x "$VERSION_DIR/AppRun" ]]; then
  echo "No Hookshot Builder install under $BUILDER_HOME/versions" >&2
  echo "Open the Hookshot AppImage once so it installs the builder, then retry." >&2
  exit 1
fi

TOOLS_SRC="$VERSION_DIR/usr/share/hookshot"
TOOLS_DST="${XDG_CACHE_HOME:-$HOME/.cache}/hookshot-deck-fork-tools"
LIB="$VERSION_DIR/usr/lib/hookshot"
PY="$VERSION_DIR/usr/python/bin/python3"
LOG="${XDG_CACHE_HOME:-$HOME/.cache}/hookshot-deck-rebuild.log"

if [[ ! -f "$GAME/image.bin" || ! -x "$GAME/bin/hookshot" ]]; then
  echo "Game folder looks incomplete: $GAME (need image.bin and bin/hookshot)" >&2
  exit 1
fi
if [[ ! -f "$FORK/gpu/vk/vk_deck.cpp" ]]; then
  echo "This does not look like the fork checkout (missing gpu/vk/vk_deck.cpp): $FORK" >&2
  exit 1
fi
if [[ ! -x "$PY" ]]; then
  echo "Builder python missing: $PY" >&2
  exit 1
fi

echo "==> Builder: $VERSION_DIR"
echo "==> Fork:    $FORK"
echo "==> Game:    $GAME"
echo "==> Log:     $LOG"

echo "==> Sync builder tools + overlay fork sources"
mkdir -p "$TOOLS_DST"
rsync -a --delete \
  --exclude '.git' \
  --exclude 'work/' \
  "$TOOLS_SRC"/ "$TOOLS_DST"/
# Overlay the bits we changed / need from the fork (renderer + docs). Keep builder's work/ and third_party tools.
rsync -a "$FORK/gpu/" "$TOOLS_DST/gpu/"
rsync -a "$FORK/docs/" "$TOOLS_DST/docs/" 2>/dev/null || true

# AppImage never compiles the Vulkan back end on-device (it ships a prebuilt .so). Point RX_CPM at headers
# from a local Eglantine/Eden cache, and fetch SPIRV-Headers if needed.
CPM="${XDG_CACHE_HOME:-$HOME/.cache}/hookshot-deck-cpm"
EG_CPM=""
for cand in \
  "$HOME/src/eglantine-upstream/.cache/cpm" \
  "$HOME/src/Eglantine/.cache/cpm" \
  "$HOME/src/eden-nx2/.cache/cpm"
do
  if [[ -d "$cand/vulkanheaders" && -d "$cand/vulkanmemoryallocator" ]]; then
    EG_CPM="$cand"
    break
  fi
done
if [[ -z "$EG_CPM" ]]; then
  echo "Need vulkanheaders + vulkanmemoryallocator under ~/src/*/ .cache/cpm (Eglantine/Eden)." >&2
  exit 1
fi
mkdir -p "$CPM"
ln -sfn "$EG_CPM/vulkanheaders" "$CPM/vulkanheaders"
ln -sfn "$EG_CPM/vulkanmemoryallocator" "$CPM/vulkanmemoryallocator"
if [[ ! -f "$CPM/spirv-headers/v1/include/spirv/unified1/spirv.h" ]]; then
  echo "==> Fetching SPIRV-Headers for CPM"
  rm -rf "$CPM/spirv-headers"
  mkdir -p "$CPM/spirv-headers"
  git clone --depth 1 --branch vulkan-sdk-1.4.309.0 \
    https://github.com/KhronosGroup/SPIRV-Headers.git "$CPM/spirv-headers/v1"
fi

export HOOKSHOT_TOOLS="$TOOLS_DST"
export EMSDK="$LIB/emsdk"
export HOOKSHOT_SYSROOT="$LIB/sysroot"
export HOOKSHOT_FFMPEG="$LIB/ffmpeg"
export HOOKSHOT_SDL2="$LIB/libSDL2-2.0.so.0"
export RX_CPM="$CPM"
# Critical: do NOT use the AppImage's prebuilt .so — compile ours
unset HOOKSHOT_VK_PREBUILT || true
export RX_VK_ONLY=1
export PATH="$LIB/emsdk/upstream/bin:$PATH"
export HOOKSHOT_JOBS="${HOOKSHOT_JOBS:-$(nproc)}"

echo "==> RX_CPM=$RX_CPM"
echo "==> Compiling Vulkan back end from fork (RX_VK_ONLY=1)…"
# Keep the builder's nx2/make_game.py (must match its nup.py). Only gpu/ is from the fork.
# --update reuses the game folder's dump; RX_VK_ONLY skips recompiling lifted game C.
set +e
"$PY" -I "$HOOKSHOT_TOOLS/nx2/make_game.py" --update "$GAME" --jobs "$HOOKSHOT_JOBS" \
  2>&1 | tee "$LOG"
rc=${PIPESTATUS[0]}
set -e
if [[ $rc -ne 0 ]]; then
  echo "Build failed (exit $rc). See $LOG" >&2
  exit $rc
fi

if ! rg -q "Vulkan back end|vk_.*\\.o|hookshot_vk\\.so" "$LOG"; then
  echo "Build log shows no Vulkan back-end compile — refusing to leave an old .so in place." >&2
  rg -n "Vulkan|RX_CPM|cpm|header|error|fail|prebuilt|as built" "$LOG" | head -40 >&2 || true
  exit 1
fi

# make_game installs beside the game; ensure bin/ has the new .so
if [[ -f "$GAME/hookshot_vk.so" ]]; then
  mkdir -p "$GAME/bin"
  cp -f "$GAME/hookshot_vk.so" "$GAME/bin/hookshot_vk.so"
fi
if [[ -f "$GAME/bin/hookshot_vk.so" ]]; then
  echo "==> Installed: $GAME/bin/hookshot_vk.so"
  ls -la "$GAME/bin/hookshot_vk.so"
  if ! strings "$GAME/bin/hookshot_vk.so" | rg -q "fork defaults on"; then
    echo "Warning: new .so missing 'fork defaults on' string — vk_deck may not have linked." >&2
    exit 1
  fi
else
  echo "Warning: hookshot_vk.so not found in game folder after build" >&2
  exit 1
fi

echo
echo "Done. Start the game the same way as before, e.g.:"
echo "  $GAME/bin/hookshot"
echo "Look in hookshot_log.txt for: Steam Deck (VANGOGH): fork defaults on"

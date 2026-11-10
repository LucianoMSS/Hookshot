# Steam Deck (RADV VANGOGH) fork notes

Branch: `deck-vangogh-defaults` on [LucianoMSS/Hookshot](https://github.com/LucianoMSS/Hookshot).

Built on current upstream `main` (includes mesh-fallback SPIR-V fixes #1314 / #1317 / #1383 that v2.0.11 lacks).

## Why rebuild

Env-only `RX_VK_FORCE_MESH_FALLBACK=1` on **v2.0.11**:
- avoided the classic outdoor `device lost` / black-screen GPU reset;
- RADV faulted compiling thousands of fallback compute pipelines → glitches, ~7 fps;
- memory ballooned → SteamOS **earlyoom** SIGTERM’d Hookshot at the door (`window closed, exiting`).

A rebuild of this branch is what picks up the newer fallback code **and** the Deck defaults below.

## Automatic on Van Gogh (`deck_apply_vangogh_defaults`)

Applied only when each switch is **unset**. Master kill switch: `RX_VK_DECK_DEFAULTS=0`.

| Default | Purpose |
|---|---|
| `RX_VK_FORCE_MESH_FALLBACK=1` | Outdoor / Deku Tree native mesh hang (#1000, #1318). Override: `RX_VK_DECK_NATIVE_MESH=1` |
| `RX_VK_MESH_NOCULL=2c56dc1006942f74` | Cull-task hang without dropping models (#817). Prefer over `SKIP_CODE` |
| `RX_VK_LOW_SPEC=1` | Minimum options preset on first run |
| `HOS_HANDHELD=1` | Handheld resolution profile |
| `RX_VK_VRAM_MB=1800` | Texture budget headroom vs earlyoom (guest needs ~10 GB RAM) |
| `RX_VK_TEX_MAX_MB=512` | Cap huge textures |
| `RX_VK_TEX_MAX_DIM=1024` | Deck shared-RAM guidance in upstream comments |
| `RX_VK_TEX_SKIP_MB=32` | Drop ASTC top levels earlier |
| `RX_VK_ASTC_BC_ALL=1` | Keep large ASTC as BC3 (¼ VRAM) |
| `RX_VK_KEEP_RETIRED=1` | Avoid give-back races seen on AMD APUs |
| `RX_VK_WB_SHADOW_MB=256` | Cap write-back shadow VRAM on integrated |
| `RX_VK_CHECKPOINTS=1` | Markers if a device lost still happens |
| Fault vendor binary off | RADV hang dumps can reach disk (#1000) |

Do **not** set `RX_VK_SKIP_CODE` for Deck play: it hides geometry and still fails outdoors.

## Build / test on Deck

```bash
# source (already cloned)
cd ~/src/Hookshot
git fetch origin && git checkout deck-vangogh-defaults && git pull

# build into a game folder (AppImage --cli or make_game.py — ~40 min)
# then clear hookshot_env.txt overrides so fork defaults apply, or keep only:
#   RX_VK_DECK_NATIVE_MESH=1   # A/B native hang
#   RX_VK_DECK_DEFAULTS=0      # all fork defaults off
```

Confirm in `hookshot_log.txt`:
- `Steam Deck (VANGOGH): fork defaults on`
- `no mesh shaders: task and mesh programs run as compute shaders`
- outdoor door save: no earlyoom, picture not black, no `device lost`

## Paths

| Role | Path |
|---|---|
| Mac Cursor workspace | `/Users/luislucianoms/hookshot-src` |
| Deck source clone | `/home/deck/src/Hookshot` |
| Playable install | `/home/deck/Games/Hookshot` |

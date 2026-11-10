# Steam Deck (RADV VANGOGH) fork notes

This fork branch (`deck-vangogh-defaults`) adds Deck-only defaults aimed at the outdoor /
post-door GPU hang tracked in upstream [#1000](https://github.com/NotRexed/Hookshot/issues/1000)
and [#1318](https://github.com/NotRexed/Hookshot/issues/1318).

## Automatic on Van Gogh

| Default | Why | Override |
|---|---|---|
| Mesh **compute fallback** (same as `RX_VK_FORCE_MESH_FALLBACK=1`) | Native task/mesh draws hang the GPU outdoors; skip lists move the hang | `RX_VK_DECK_NATIVE_MESH=1` or `RX_VK_FORCE_MESH_FALLBACK=0` |
| `RX_VK_MESH_NOCULL=2c56dc1006942f74` | Cull task hang (#817) without dropping models | `RX_VK_MESH_NOCULL=0` |

Do **not** use `RX_VK_SKIP_CODE=2c56dc1006942f74` as the primary workaround: it hides geometry
(broken picture inside the house) and still does not stop the outdoor hang.

## What we still do not know

On stock **v2.0.11**, forcing the mesh fallback avoided resets for some Deck testers but drew
**black** (fallback SPIR-V bugs). Upstream merged fallback fixes (#1314, #1317, #1383) for
v2.0.12 — this branch is based on current `main` so those fixes are included. Outdoor playability
still needs a Deck rebuild + the door save.

## Build / test on Deck

1. Build from this fork (AppImage toolchain or `python -I nx2/make_game.py ...`) into a game folder.
2. Load the save **outside Link’s door** (not the interior house save).
3. Confirm the log has:
   - `Steam Deck (VANGOGH): mesh compute fallback on`
   - `no mesh shaders: task and mesh programs run as compute shaders`
   - `RX_VK_MESH_NOCULL=... on` (or your explicit value)
4. A/B: `RX_VK_DECK_NATIVE_MESH=1` should restore the native hang for comparison.

## Quick A/B without rebuilding

On an existing v2.0.11 install, `hookshot_env.txt` can already set:

```ini
RX_VK_FORCE_MESH_FALLBACK=1
RX_VK_MESH_NOCULL=2c56dc1006942f74
```

Expect: no reset **or** black picture on 2.0.11. A fork build of `main`+this branch is the real test.

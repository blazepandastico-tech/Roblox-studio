---
name: stud-voxel-models
description: Make stud / brick-style voxel models for Roblox with this repo's StudVox toolkit — pets and critters with idle/walk/action clips, bosses and mobs, buildings, props, nature, modular terrain tiles, weapons (exported as Tools), or a model traced from a reference picture. Use whenever the user asks for a Roblox model, pet, boss, prop, building, terrain piece or weapon "in stud style", "a mattoncini", "voxel", "LEGO-like", or wants a picture turned into a voxel model.
---

# Stud-style voxel models

1. **Decide category and scale.** Default studs per voxel: eggs, bosses, buildings, props, nature and terrain 1.0 ·
   mobs 0.5 · critters 0.25 · weapons 0.125. Roblox's native Studs surface lines up 1:1 only at 1.0, so
   suggest 1.0 when the model will be big in game anyway.
2. **Write the spec** `models/<category>/<name>.py`:
   ```python
   from studvox import Model, S
   from studvox.kit import face, idle_breathe, walk_quad, walk_biped, hop, flap, wave_chain, attack_lunge
   def build() -> Model:
       m = Model("<name>", title="<Title>", category="<category>", description="<one line>")
       body = m.part("body", pivot=(0, 4, 0))
       ...
       return m
   ```
   * Author space: +X right, +Y up, **+Z is the front**. Model on one side and `symmetrize("x")`, or use `mirror_part`.
   * Rig parts = bones; give each a pivot at its joint. Limbs, heads, tails, wings and jaws become separate parts.
   * Clips: an `idle` loop, a `walk` loop and one action (`attack`, `roar`, `jump`, ...). Make periods divide the clip length.
   * Faces: `face(head, "cute", y=...)` or `part.decal([...], at=(x, y, 0), colors={...})`.
   * Terrain: `m.tile(16)` and keep voxels inside the footprint. Weapons: `m.grip(pos, forward=..., up=...)`.
   * Reference pictures: `python -m studvox trace <image> --name <name>` instead of hand-modelling.
3. **Check, then render quickly**:
   `python -m studvox bake models/<category>/<name>.py` and then
   `python -m studvox make models/<category>/<name>.py --quick --no-export`.
4. **Look at the result.** Read `out/<category>/<name>/renders/hero.png` and the `sheet.jpg`. Fix the
   proportions, colours and silhouette, and repeat step 3 until it reads well at thumbnail size.
5. **Final build**: `python -m studvox make models/<category>/<name>.py` (add `--gif` for an animated preview), then
   `python -m studvox gallery`.
6. **Report** the files (`out/<category>/<name>/<name>.rbxmx`, `.luau`, `.fbx`, `.glb`, `sheet.jpg`) and how to import them:
   drag the `.rbxmx` into Studio. It plays the clip set in the `Clip` StringValue.

Studs are never geometry: Plastic parts with `TopSurface = Studs` in Roblox, and flat studs in renders and meshes.
Full API: `docs/API.md`.

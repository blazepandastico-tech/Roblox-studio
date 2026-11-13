# StudVox (Claude Code guide)

This repo turns requests like "make me a stud-style dragon boss for Roblox" into stud/brick voxel models:
a Python spec → Blender build (flat studs, black outline, rig, clips) → renders + concept sheet → Studio-ready
`.rbxmx` / `.luau` (+ FBX/GLB/OBJ).

The user writes in Italian: reply in Italian unless they switch.

## Workflow for a new model

1. Pick the category and scale (`docs/API.md`). Native Roblox studs line up 1:1 only at `voxel_size = 1`.
2. Write `models/<category>/<name>.py` with `build() -> Model`. Reuse `studvox.kit` (faces, idle and walk
   clips) and keep proportions chunky and readable: big heads for pets, 2–3 tones per material, faces
   with `decal`.
3. Iterate fast: `python -m studvox bake <spec>` (sizes and part counts), then
   `python -m studvox make <spec> --quick --no-export`. **Look at** `out/<cat>/<name>/renders/hero.png`
   (and the sheet) with the Read tool, then fix the proportions and render again.
4. Final build: `python -m studvox make <spec>` (add `--gif` for an animated preview). Run
   `python -m studvox gallery` when you add non-egg models.
5. Tell the user where the files are and how to import them (README → "Importing into Roblox Studio").

## Eggs (14 biomes × 10 rarities)

* Specs live in `models/eggs/<biome>/<id>.py` (`EggDesign` + `build_egg`). The toolkit is in `studvox/eggs.py`:
  egg shape, `PATTERNS`, `EXTRAS`, the rarity/biome/mutation tables and the automatic rarity effects.
* After adding or changing eggs, run
  `python -m studvox make models/eggs/<biome> --hero-only --no-export --size 640 --samples 28`, then
  `python -m studvox eggpack`. That regenerates `roblox/eggs/EggConfig.luau`, `out/eggs/EggPack.rbxmx`,
  `docs/eggs/*.jpg` and `docs/eggs/LISTA_UOVA.md`.
* Egg designs must be **original**. Do not copy names, pets or art from existing games; the research notes
  in `docs/RICERCA_STEAL_AN_EGG.md` describe structure only.

## Rules that matter

* Studs: never model them as geometry. Roblox exports use Plastic parts with `TopSurface = Studs` /
  `BottomSurface = Inlet` (or `Universal`), the `texture` mode for sub-stud voxels, and flat bump-shaded
  studs in renders.
* Author space is +X right, +Y up, +Z front. Every clip must reference existing parts; looping clips should be
  seamless (periods that divide the length).
* Keep Roblox part counts sane: `bake` prints them (boxes merge through hidden interior voxels).
  Speckle-heavy models cost more parts.
* Luau lives in `roblox/`: check syntax with `stylua --check --syntax luau roblox/` when it is installed.
* Rendering needs Blender (`python -m studvox doctor`). `.venv-bpy` / `STUDVOX_BLENDER` are picked up
  automatically.
* Don't commit renders or mesh exports (`.gitignore` already excludes them). Studio files, sheets and
  previews are committed.

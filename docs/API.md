# StudVox API

A model spec is a Python file with `build() -> studvox.Model`. Coordinates are voxel units in
**author space: +X right, +Y up, +Z front** (the side the model faces). A voxel at integer `(x, y, z)` is a
unit cube centred on that point; use half-integer centres for even-sized shapes.

## Model

```python
Model(name, *, title=None, category="props", description="", voxel_size=None, tags=(), origin="auto")
```

| Member | Purpose |
|---|---|
| `category` | `eggs`, `critters`, `bosses`, `mobs`, `buildings`, `props`, `nature`, `terrain`, `weapons`, `traced`; sets the default `voxel_size` (studs per voxel) |
| `voxel_size` | eggs, bosses, buildings, props, nature and terrain 1.0 · mobs 0.5 · critters and traced 0.25 · weapons 0.125 |
| `part(name, *, parent=None, pivot=None, studs=True)` | add a rig part (bone). Parents must exist first; `pivot` is the rotation point |
| `mirror_part(src, dst, *, axis="x", center=0.0)` | mirrored copy (`leg_l` → `leg_r`) |
| `clip(name, length, *, loop=True, fps=24)` | add an animation clip |
| `add_color(name, hex, material="plastic", *, studs=None)` | custom colour (`plastic`, `matte`, `metal`, `glow`, `glass`, `water`) |
| `tile(size_x, size_z=None, *, ground=0)` | modular terrain tile: footprint centred on the origin, snaps on a `size × voxel_size` grid |
| `grip(pos, *, forward, up)` | weapons: hand position plus the directions that point away from the player and up; exports a Roblox `Tool` |
| `outline` | outline thickness in voxels (`"auto"`) |
| `stud_mode` | `"top"` (flat stud on every open top face) or `"none"` |
| `roblox` | `studs` (`auto`/`surface`/`universal`/`texture`/`none`), `stud_texture`, `anchored`, `collide`, `highlight`, `default_clip` |
| `meta`, `notes` | free data; notes appear on static concept sheets |

Colours are palette names (`studvox/palette.py`: `red`, `light_blue`, `gold`, `neon_cyan`, `glass`, ...),
`"#rrggbb"`, or `("#rrggbb", "material")`. Glow colours have no studs; glass and water are see-through, and
whatever is inside them is drawn.

## Part

Adding: `add(coords, color, *, stud=None)`, `voxel`, `voxels`, `box(a, b)`, `box_c(center, size)`,
`ellipsoid(center, radii)`, `sphere`, `cylinder(base, radius, height, axis="y", top_radius=None)`, `cone`,
`disc`, `line(a, b, radius=0)`, `tube(points, radii)`, `roof(a, b, ridge="x")`, `pyramid`, `stairs(a, b, rise="+z")`,
`blob(center, radii, noise=0.25, seed=0)`.

Editing: `carve(coords)`, `paint(coords, color, only=None)`, `paint_where(fn(x, y, z) -> mask, color)`,
`paint_top(color, depth=1)`, `speckle({"stone": .6, "dark_stone": .4})`, `symmetrize(axis="x")`,
`move(d)`, `take(coords, into=other_part)`.

Faces and details: `decal(rows, at=(x, y, z), colors={"B": "black"}, facing="+z")` paints ASCII art on
the outermost voxels; `emboss(...)` adds it on top of the surface. `.` or a space means skip.

Shapes on their own live in `studvox.shapes` (`S`): the same primitives return coordinate arrays, together
with `union`, `difference`, `intersect`, `translate`, `mirror`, `rotate90`, `hollow`, `scatter`, `half`, `ring`,
`torus` and `noise3`.

## Clips

```python
c = m.clip("walk", 0.8)
c.osc("leg_l", rot=(30, 0, 0), period=0.8)            # sin, cos, bounce, square, saw, tri
c.osc("body", pos=(0, 0.5, 0), period=0.4, wave="bounce")
c.hold("wing_l", rot=(0, 0, 20))                       # constant offset
c.spin("rotor", "y", turns=1)                          # continuous rotation
c.keys("head", [(0, {}), (0.3, {"rot": (-20, 0, 0)}), (0.6, {"pos": (0, 1, 0), "ease": "back"}), (1.0, {})])
```

Positions are in voxels; rotations are degrees, Euler XYZ, about the parent's axes. Eases are
`linear`, `smooth`, `in`, `out`, `back` and `step`. Contributions add up and are baked at `fps`.

`studvox.kit` has ready-made pieces: `face(part, "cute" | rows, y=...)`, `idle_breathe`, `walk_biped`,
`walk_quad`, `hop`, `flap`, `wave_chain` (tails, tentacles), and `attack_lunge`.

## Eggs

```python
from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="frost_spiral_egg", name="Frost Spiral Egg", biome="tundra", rarity="mythic",
    base="light_blue", accent="white",
    patterns=[("swirl", {"count": 3, "twist": 6.0, "color": "white"})],
    extras=[("crystals", {"color": "ice"}), ("flame", {"outer": "neon_cyan", "inner": "sky"})],
    flavor="Burns cold.",
)
def build():
    return build_egg(DESIGN)
```

Patterns and accessories are listed in [UOVA.md](UOVA.md). Colour references inside patterns can be
`base`, `accent`, `accent2`, `accent3`, `glow` (the rarity effect colour) or `rarity`. Size, aura, sparkles,
halo and wings follow the rarity. The economy tables are `RARITIES`, `BIOMES` and `MUTATIONS` in
`studvox/eggs.py`.

## Tracing pictures

`python -m studvox trace picture.png --name thing [--height 40] [--depth 0] [--colors 12] [--side side.png]`
removes the background (alpha, or a flood fill from the border colour) and resamples the picture to the grid
by the most common colour in each cell. It then quantises the colours, keeps dark line-art as black voxels and
inflates the silhouette into a rounded body. The spec is written to `models/traced/thing.py`.

## Outputs

`out/<category>/<name>/`: `<name>.svox.json` (baked model), `<name>.rbxmx`, `<name>.luau`,
`renders/` (hero, front, side, back, poses), `preview.jpg`, `sheet.jpg`, `stats.json`, and with exports
`<name>.fbx` / `.glb` / `.obj` + `_palette.png` + `anims/`.

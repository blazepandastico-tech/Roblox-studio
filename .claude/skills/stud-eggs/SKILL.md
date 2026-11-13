---
name: stud-eggs
description: Create or change collectible eggs for egg-stealing / egg-hatching Roblox games with this repo's egg kit (14 biomes x 10 rarities, mutations, EggConfig, EggPack.rbxmx). Use when the user asks for new eggs, a new biome of eggs, egg rarities, egg mutations, egg spawn/hatch/income numbers, or the egg pack for Studio ("uova", "nuovo uovo", "biomi", "rarità", "mutazioni").
---

# Stud-style eggs

Eggs are specs in `models/eggs/<biome>/<id>.py`:

```python
from studvox.eggs import EggDesign, build_egg
DESIGN = EggDesign(
    id="<id>", name="<Name> Egg", biome="<biome id>", rarity="<rarity id>",
    base="<shell colour>", accent="<pattern colour>", accent2="white", accent3="black",
    patterns=[("swirl", {"count": 3, "twist": 6.0, "color": "accent"}), ...],
    extras=["sprout", ("crown", {"color": "gold", "gem": "red"}), ...],
    flavor="<one short line>",
)
def build():
    return build_egg(DESIGN)
```

* Biomes: meadow, pond, dunes, jungle, tundra, caldera, reef, fossil, candy, clockwork, haunted, blossom, starlight, sky.
  Rarities: common, uncommon, rare, epic, legendary, mythic, celestial, secret, eternal, divine.
  New biomes and rarities, and their numbers, go in the tables at the top of `studvox/eggs.py`.
* Patterns and accessories are the `PATTERNS` / `EXTRAS` dicts in `studvox/eggs.py` (also listed in
  `docs/UOVA.md`). Add a new `x_<name>` / `p_<name>` function there when a design needs something new.
* Rarer = bigger and fancier. Legendary and above get an aura ring, celestial gets sparkles, and divine gets a halo
  and wings automatically. Secret eggs read dark and mysterious, and eternal eggs often use a glass shell
  (`("#hex", "glass")`) with an `inner` core.
* Keep every design original; don't reuse names or creatures from existing games.

Build and check:

```bash
python -m studvox bake models/eggs/<biome>/<id>.py
python -m studvox make models/eggs/<biome>/<id>.py --hero-only --no-export --quick   # then Read renders/hero.png
python -m studvox make models/eggs/<biome> --hero-only --no-export --size 640 --samples 28
python -m studvox eggpack        # EggConfig.luau + EggPack.rbxmx + docs/eggs catalogue + LISTA_UOVA.md
```

In Studio: put `out/eggs/EggPack.rbxmx` in ReplicatedStorage, `Examples/EggSpawner` in ServerScriptService and
`Examples/EggClientEffects` in StarterPlayerScripts. Tag Parts `EggSpawn` with a `Biome` attribute. Game
numbers and helpers are in `EggConfig`: `RollEgg`, `RollWeight`, `RollMutation`, `Income`, `HatchSeconds`,
`ScaleForWeight`, `CarrySpeedMultiplier` and `FormatMoney`.

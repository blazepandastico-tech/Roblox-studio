"""Pebble Egg: Lily Pond · Uncommon egg. Smooth from a thousand ripples."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="pebble_egg",
    name="Pebble Egg",
    biome="pond",
    rarity="uncommon",
    base="stone",
    accent="gray",
    accent2="white",
    accent3="black",
    patterns=[
        ("speckle", {"colors": {"gray": 2, "dark_stone": 1, "light_gray": 2}, "fraction": 0.5, "seed": 5}),
        ("cap", {"from": 0.88, "color": "moss"}),
    ],
    extras=[],
    flavor="Smooth from a thousand ripples.",
)


def build():
    return build_egg(DESIGN)

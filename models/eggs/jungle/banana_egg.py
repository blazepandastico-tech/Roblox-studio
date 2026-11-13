"""Banana Egg: Vine Jungle · Uncommon egg. Ripe and ready to hatch."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="banana_egg",
    name="Banana Egg",
    biome="jungle",
    rarity="uncommon",
    base="yellow",
    accent="mustard",
    accent2="white",
    accent3="black",
    patterns=[
        ("stripes", {"count": 4, "color": "light_yellow", "y": (0.1, 0.9)}),
        ("cap", {"from": 0.92, "color": "dark_brown"}),
    ],
    extras=[],
    flavor="Ripe and ready to hatch.",
)


def build():
    return build_egg(DESIGN)

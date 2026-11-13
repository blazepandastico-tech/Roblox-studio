"""Honeycomb Egg: Clover Meadow · Legendary egg. Sticky, sweet and buzzing."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="honeycomb_egg",
    name="Honeycomb Egg",
    biome="meadow",
    rarity="legendary",
    base="yellow",
    accent="mustard",
    accent2="white",
    accent3="black",
    patterns=[
        ("scales", {"count": 8, "color": "mustard"}),
        ("bands", {"at": (0.3, 0.55), "width": 2, "color": "black"}),
    ],
    extras=[
        ("honey_drip", {"color": "gold"}),
        ("wings", {"color": ("#DDF4FF", "glass"), "tip": "light_blue", "size": 4}),
    ],
    flavor="Sticky, sweet and buzzing.",
)


def build():
    return build_egg(DESIGN)

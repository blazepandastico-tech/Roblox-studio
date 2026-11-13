"""Sunpetal Egg: Clover Meadow · Divine egg. The first flower of the first spring."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="sunpetal_egg",
    name="Sunpetal Egg",
    biome="meadow",
    rarity="divine",
    base="light_yellow",
    accent="gold",
    accent2="white",
    accent3="black",
    patterns=[
        ("zigzag", {"at": 0.45, "teeth": 10, "width": 1, "color": "gold"}),
        ("cap", {"from": 0.86, "color": "white"}),
    ],
    extras=[
        ("flower", {"petal": "gold", "center": "white", "stem": "green"}),
        ("wings", {"color": "white", "tip": "gold"}),
    ],
    flavor="The first flower of the first spring.",
)


def build():
    return build_egg(DESIGN)

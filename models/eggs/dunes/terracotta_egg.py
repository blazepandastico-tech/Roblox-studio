"""Terracotta Egg: Sunbaked Dunes · Rare egg. Painted by hand, baked by the sun."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="terracotta_egg",
    name="Terracotta Egg",
    biome="dunes",
    rarity="rare",
    base=("#C96A3B", "matte"),
    accent="cream",
    accent2="white",
    accent3="black",
    patterns=[
        ("zigzag", {"at": 0.48, "teeth": 8, "width": 1, "color": "cream"}),
        ("bands", {"at": (0.3, 0.68), "width": 1, "color": "dark_brown"}),
    ],
    extras=[],
    flavor="Painted by hand, baked by the sun.",
)


def build():
    return build_egg(DESIGN)

"""Sunstone Egg: Sunbaked Dunes · Mythic egg. Stores a whole day of sunshine."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="sunstone_egg",
    name="Sunstone Egg",
    biome="dunes",
    rarity="mythic",
    base="orange",
    accent="yellow",
    accent2="white",
    accent3="black",
    patterns=[
        ("gradient", {"stops": ((0.6, "yellow"),)}),
        ("cracks", {"count": 4, "length": 8, "color": "neon_yellow", "seed": 6}),
    ],
    extras=[("rays", {"color": "fire"})],
    flavor="Stores a whole day of sunshine.",
)


def build():
    return build_egg(DESIGN)

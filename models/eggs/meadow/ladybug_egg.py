"""Ladybug Egg: Clover Meadow · Epic egg. Seven spots, zero worries."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="ladybug_egg",
    name="Ladybug Egg",
    biome="meadow",
    rarity="epic",
    base="red",
    accent="black",
    accent2="white",
    accent3="black",
    patterns=[
        ("spots", {"count": 7, "size": 1.0, "color": "black", "seed": 4}),
        ("cap", {"from": 0.84, "color": "black"}),
    ],
    extras=[("antenna", {"color": "black", "tip": "black"})],
    flavor="Seven spots, zero worries.",
)


def build():
    return build_egg(DESIGN)

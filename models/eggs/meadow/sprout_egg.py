"""Sprout Egg: Clover Meadow · Common egg. A tiny sprout pokes out of the shell."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="sprout_egg",
    name="Sprout Egg",
    biome="meadow",
    rarity="common",
    base="light_green",
    accent="green",
    accent2="white",
    accent3="black",
    patterns=[
        ("spots", {"count": 5, "size": 0.8, "color": "cream", "seed": 2}),
        ("bottom", {"to": 0.12, "color": "green"}),
    ],
    extras=["sprout"],
    flavor="A tiny sprout pokes out of the shell.",
)


def build():
    return build_egg(DESIGN)

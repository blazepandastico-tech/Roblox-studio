"""Daisy Egg: Clover Meadow · Rare egg. Smells like a sunny morning."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="daisy_egg",
    name="Daisy Egg",
    biome="meadow",
    rarity="rare",
    base="cream",
    accent="yellow",
    accent2="white",
    accent3="black",
    patterns=[("zigzag", {"at": 0.3, "teeth": 8, "width": 2, "color": "light_green"})],
    extras=[("flower", {"petal": "white", "center": "yellow", "stem": "green"})],
    flavor="Smells like a sunny morning.",
)


def build():
    return build_egg(DESIGN)

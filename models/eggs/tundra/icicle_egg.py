"""Icicle Egg: Frostpeak Tundra · Rare egg. Drip, drip, freeze."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="icicle_egg",
    name="Icicle Egg",
    biome="tundra",
    rarity="rare",
    base="sky",
    accent="ice",
    accent2="white",
    accent3="black",
    patterns=[("bottom", {"to": 0.18, "color": "blue"})],
    extras=[("icicles", {"color": "ice", "at": 0.64})],
    flavor="Drip, drip, freeze.",
)


def build():
    return build_egg(DESIGN)

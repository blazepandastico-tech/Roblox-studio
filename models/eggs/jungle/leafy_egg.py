"""Leafy Egg: Vine Jungle · Common egg. Wrapped up warm in jungle leaves."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="leafy_egg",
    name="Leafy Egg",
    biome="jungle",
    rarity="common",
    base="light_green",
    accent="green",
    accent2="white",
    accent3="black",
    patterns=[("vines", {"color": "green", "turns": 2, "twist": 7.0, "leaf": "dark_green"})],
    extras=[],
    flavor="Wrapped up warm in jungle leaves.",
)


def build():
    return build_egg(DESIGN)

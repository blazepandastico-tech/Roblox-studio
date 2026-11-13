"""Pumpkin Egg: Haunted Hollow · Common egg. Carve it? It might carve you."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="pumpkin_egg",
    name="Pumpkin Egg",
    biome="haunted",
    rarity="common",
    base="orange",
    accent="dark_orange",
    accent2="white",
    accent3="black",
    patterns=[("stripes", {"count": 6, "color": "dark_orange"})],
    extras=[("stem", {"color": "dark_brown", "leaf": "green"})],
    flavor="Carve it? It might carve you.",
)


def build():
    return build_egg(DESIGN)

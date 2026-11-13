"""Sunvine Egg: Vine Jungle · Divine egg. Vines of light climb towards the sun."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="sunvine_egg",
    name="Sunvine Egg",
    biome="jungle",
    rarity="divine",
    base="white",
    accent="gold",
    accent2="white",
    accent3="black",
    patterns=[("vines", {"color": "gold", "turns": 3, "twist": 8.0, "leaf": "lime"})],
    extras=[("flower", {"petal": "gold", "center": "white"}), ("wings", {"color": "white", "tip": "lime"})],
    flavor="Vines of light climb towards the sun.",
)


def build():
    return build_egg(DESIGN)

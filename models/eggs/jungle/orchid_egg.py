"""Orchid Egg: Vine Jungle · Rare egg. A rare bloom from the canopy."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="orchid_egg",
    name="Orchid Egg",
    biome="jungle",
    rarity="rare",
    base="lavender",
    accent="violet",
    accent2="white",
    accent3="black",
    patterns=[("spots", {"count": 6, "size": 0.9, "color": "violet", "seed": 6})],
    extras=[("flower", {"petal": "hot_pink", "center": "yellow", "stem": "dark_green"})],
    flavor="A rare bloom from the canopy.",
)


def build():
    return build_egg(DESIGN)

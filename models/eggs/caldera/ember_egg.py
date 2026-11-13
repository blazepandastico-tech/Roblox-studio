"""Ember Egg: Ember Caldera · Legendary egg. Its little flame never goes out."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="ember_egg",
    name="Ember Egg",
    biome="caldera",
    rarity="legendary",
    base="dark_red",
    accent="orange",
    accent2="white",
    accent3="black",
    patterns=[("gradient", {"stops": ((0.55, "red"), (0.8, "orange"))})],
    extras=["flame"],
    flavor="Its little flame never goes out.",
)


def build():
    return build_egg(DESIGN)

"""Candy Cane Egg: Sugar Isles · Legendary egg. Peppermint stripes all the way round."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="candy_cane_egg",
    name="Candy Cane Egg",
    biome="candy",
    rarity="legendary",
    base="white",
    accent="red",
    accent2="white",
    accent3="black",
    patterns=[("swirl", {"count": 4, "twist": 8.0, "color": "red"})],
    extras=[("bow", {"color": "green", "knot": "red"})],
    flavor="Peppermint stripes all the way round.",
)


def build():
    return build_egg(DESIGN)

"""Lollipop Egg: Sugar Isles · Rare egg. Lick at your own risk."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="lollipop_egg",
    name="Lollipop Egg",
    biome="candy",
    rarity="rare",
    base="white",
    accent="hot_pink",
    accent2="white",
    accent3="black",
    patterns=[("swirl", {"count": 3, "twist": 5.0, "color": "hot_pink"})],
    extras=[],
    flavor="Lick at your own risk.",
)


def build():
    return build_egg(DESIGN)

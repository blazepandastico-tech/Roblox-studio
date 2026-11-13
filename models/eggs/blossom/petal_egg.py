"""Petal Egg: Blossom Hills · Common egg. Dusted with falling petals."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="petal_egg",
    name="Petal Egg",
    biome="blossom",
    rarity="common",
    base="blush",
    accent="pink",
    accent2="white",
    accent3="black",
    patterns=[("spots", {"count": 7, "size": 0.7, "color": "pink", "seed": 9})],
    extras=[],
    flavor="Dusted with falling petals.",
)


def build():
    return build_egg(DESIGN)

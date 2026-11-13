"""Origami Egg: Blossom Hills · Epic egg. Folded from a single sheet of paper."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="origami_egg",
    name="Origami Egg",
    biome="blossom",
    rarity="epic",
    base="white",
    accent="pink",
    accent2="white",
    accent3="black",
    patterns=[("diamonds", {"count": 6, "rows": 3.0, "color": "pink"})],
    extras=[],
    flavor="Folded from a single sheet of paper.",
)


def build():
    return build_egg(DESIGN)

"""Gumdrop Egg: Sugar Isles · Common egg. Covered in sugary gumdrops."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="gumdrop_egg",
    name="Gumdrop Egg",
    biome="candy",
    rarity="common",
    base="pink",
    accent="hot_pink",
    accent2="white",
    accent3="black",
    patterns=[],
    extras=[("gumdrops", {})],
    flavor="Covered in sugary gumdrops.",
)


def build():
    return build_egg(DESIGN)

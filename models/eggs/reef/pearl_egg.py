"""Pearl Egg: Coral Reef · Eternal egg. The ocean's most precious secret."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="pearl_egg",
    name="Pearl Egg",
    biome="reef",
    rarity="eternal",
    base=("#F7F1FF", "metal"),
    accent="lavender",
    accent2="white",
    accent3="black",
    patterns=[("speckle", {"colors": {"lavender": 1}, "fraction": 0.08, "seed": 2})],
    extras=[("sparkles", {"color": "white"})],
    flavor="The ocean's most precious secret.",
)


def build():
    return build_egg(DESIGN)

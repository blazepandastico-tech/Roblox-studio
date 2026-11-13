"""Sugar Crystal Egg: Sugar Isles · Eternal egg. Rock candy that took a century to grow."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="sugar_crystal_egg",
    name="Sugar Crystal Egg",
    biome="candy",
    rarity="eternal",
    base=("#FFC2E8", "glass"),
    accent="hot_pink",
    accent2="white",
    accent3="black",
    patterns=[],
    extras=[("inner", {"color": "hot_pink", "shape": "gem"}), ("crystals", {"color": "crystal", "count": 6})],
    flavor="Rock candy that took a century to grow.",
)


def build():
    return build_egg(DESIGN)

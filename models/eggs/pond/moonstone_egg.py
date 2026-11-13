"""Moonstone Egg: Lily Pond · Eternal egg. Cool to the touch, even in summer."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="moonstone_egg",
    name="Moonstone Egg",
    biome="pond",
    rarity="eternal",
    base=("#CFE8FF", "glass"),
    accent="lavender",
    accent2="white",
    accent3="black",
    patterns=[],
    extras=[("inner", {"color": "lavender", "shape": "gem"}), ("crystals", {"color": "ice", "count": 5})],
    flavor="Cool to the touch, even in summer.",
)


def build():
    return build_egg(DESIGN)

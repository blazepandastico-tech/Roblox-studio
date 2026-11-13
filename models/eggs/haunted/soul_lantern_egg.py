"""Soul Lantern Egg: Haunted Hollow · Eternal egg. Lights the way through the hollow."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="soul_lantern_egg",
    name="Soul Lantern Egg",
    biome="haunted",
    rarity="eternal",
    base=("#A9FFE0", "glass"),
    accent="neon_green",
    accent2="white",
    accent3="black",
    patterns=[],
    extras=[("inner", {"color": "neon_green", "shape": "blob"}), ("lantern_ring", {"color": "gunmetal"})],
    flavor="Lights the way through the hollow.",
)


def build():
    return build_egg(DESIGN)

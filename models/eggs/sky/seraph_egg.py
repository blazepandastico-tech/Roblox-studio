"""Seraph Egg: Sky Citadel · Eternal egg. Sings softly at sunrise."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="seraph_egg",
    name="Seraph Egg",
    biome="sky",
    rarity="eternal",
    base="white",
    accent="gold",
    accent2="white",
    accent3="black",
    patterns=[
        ("zigzag", {"at": 0.45, "teeth": 8, "width": 1, "color": "gold"}),
        ("cap", {"from": 0.8, "color": "light_yellow"}),
    ],
    extras=[("gem", {"color": "neon_cyan", "at": 0.55}), ("wings", {"color": "white", "tip": "gold"})],
    flavor="Sings softly at sunrise.",
)


def build():
    return build_egg(DESIGN)

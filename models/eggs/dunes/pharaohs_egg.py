"""Pharaoh's Egg: Sunbaked Dunes · Eternal egg. Sealed in gold for three thousand years."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="pharaohs_egg",
    name="Pharaoh's Egg",
    biome="dunes",
    rarity="eternal",
    base=("#E8B32A", "metal"),
    accent="blue",
    accent2="white",
    accent3="black",
    patterns=[
        ("stripes", {"count": 10, "color": "dark_blue", "y": (0.55, 0.88)}),
        ("band", {"at": 0.5, "width": 1, "color": "black"}),
    ],
    extras=[("gem", {"color": "neon_cyan", "at": 0.38})],
    flavor="Sealed in gold for three thousand years.",
)


def build():
    return build_egg(DESIGN)

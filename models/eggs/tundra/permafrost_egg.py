"""Permafrost Egg: Frostpeak Tundra · Eternal egg. Never melts. Never."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="permafrost_egg",
    name="Permafrost Egg",
    biome="tundra",
    rarity="eternal",
    base=("#D6F3FF", "glass"),
    accent="crystal",
    accent2="white",
    accent3="black",
    patterns=[],
    extras=[
        ("inner", {"color": "crystal", "shape": "gem"}),
        ("crystals", {"color": "neon_cyan", "count": 5}),
    ],
    flavor="Never melts. Never.",
)


def build():
    return build_egg(DESIGN)

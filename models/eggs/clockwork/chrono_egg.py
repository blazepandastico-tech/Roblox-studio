"""Chrono Egg: Clockwork Works · Eternal egg. Time runs backwards inside it."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="chrono_egg",
    name="Chrono Egg",
    biome="clockwork",
    rarity="eternal",
    base=("#B8E6FF", "glass"),
    accent="gold",
    accent2="white",
    accent3="black",
    patterns=[],
    extras=[
        ("inner", {"color": "gold", "shape": "gem"}),
        ("rivets", {"color": "gold", "rows": (0.2, 0.8), "count": 8}),
    ],
    flavor="Time runs backwards inside it.",
)


def build():
    return build_egg(DESIGN)

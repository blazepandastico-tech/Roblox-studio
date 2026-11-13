"""Eruption Egg: Ember Caldera · Eternal egg. It could blow at any second."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="eruption_egg",
    name="Eruption Egg",
    biome="caldera",
    rarity="eternal",
    base="dark_stone",
    accent="lava",
    accent2="white",
    accent3="black",
    patterns=[("drips", {"from": 0.8, "color": "lava", "count": 9, "max_len": 4})],
    extras=[
        ("flame", {"outer": "lava", "inner": "neon_yellow", "core": "light"}),
        ("rays", {"color": "fire"}),
    ],
    flavor="It could blow at any second.",
)


def build():
    return build_egg(DESIGN)

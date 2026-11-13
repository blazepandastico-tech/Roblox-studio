"""Evergreen Egg: Clover Meadow · Eternal egg. A leaf that never falls, sealed in glass."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="evergreen_egg",
    name="Evergreen Egg",
    biome="meadow",
    rarity="eternal",
    base=("#3DDC84", "glass"),
    accent="lime",
    accent2="white",
    accent3="black",
    patterns=[],
    extras=[("inner", {"color": "lime", "shape": "gem"}), ("leaf_crown", {"color": "green", "count": 6})],
    flavor="A leaf that never falls, sealed in glass.",
)


def build():
    return build_egg(DESIGN)

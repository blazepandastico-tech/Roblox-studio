"""Jade Egg: Blossom Hills · Eternal egg. Carved from a single piece of jade."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="jade_egg",
    name="Jade Egg",
    biome="blossom",
    rarity="eternal",
    base=("#3FBF7F", "glass"),
    accent="gold",
    accent2="white",
    accent3="black",
    patterns=[("zigzag", {"at": 0.5, "teeth": 8, "width": 1, "color": "gold"})],
    extras=[("inner", {"color": "gold", "shape": "gem"})],
    flavor="Carved from a single piece of jade.",
)


def build():
    return build_egg(DESIGN)

"""Emerald Idol Egg: Vine Jungle · Eternal egg. Worth more than the whole temple."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="emerald_idol_egg",
    name="Emerald Idol Egg",
    biome="jungle",
    rarity="eternal",
    base=("#2BD46A", "glass"),
    accent="gold",
    accent2="white",
    accent3="black",
    patterns=[],
    extras=[("inner", {"color": "gold", "shape": "gem"}), ("crown", {"color": "gold", "gem": "red"})],
    flavor="Worth more than the whole temple.",
)


def build():
    return build_egg(DESIGN)

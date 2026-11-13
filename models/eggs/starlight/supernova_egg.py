"""Supernova Egg: Starlight Rim · Eternal egg. About to explode with light."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="supernova_egg",
    name="Supernova Egg",
    biome="starlight",
    rarity="eternal",
    base=("#B9F3FF", "glass"),
    accent="neon_yellow",
    accent2="white",
    accent3="black",
    patterns=[],
    extras=[("inner", {"color": "neon_yellow", "shape": "blob"}), ("rays", {"color": "neon_yellow"})],
    flavor="About to explode with light.",
)


def build():
    return build_egg(DESIGN)

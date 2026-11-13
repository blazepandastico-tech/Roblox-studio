"""Primeval Egg: Fossil Valley · Eternal egg. Older than the dinosaurs."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="primeval_egg",
    name="Primeval Egg",
    biome="fossil",
    rarity="eternal",
    base="forest",
    accent="lime",
    accent2="white",
    accent3="black",
    patterns=[("diamonds", {"count": 6, "rows": 3.0, "color": "lime"})],
    extras=[("crystals", {"color": ("#6BFF5E", "glass"), "count": 5})],
    flavor="Older than the dinosaurs.",
)


def build():
    return build_egg(DESIGN)

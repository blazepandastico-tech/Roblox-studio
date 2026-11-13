"""Breeze Egg: Sky Citadel · Uncommon egg. Whistles when the wind blows."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="breeze_egg",
    name="Breeze Egg",
    biome="sky",
    rarity="uncommon",
    base="light_blue",
    accent="white",
    accent2="white",
    accent3="black",
    patterns=[
        ("wave", {"at": 0.4, "amp": 1.0, "freq": 2, "width": 1, "color": "white"}),
        ("wave", {"at": 0.65, "amp": 1.0, "freq": 2, "width": 1, "color": "white"}),
    ],
    extras=[],
    flavor="Whistles when the wind blows.",
)


def build():
    return build_egg(DESIGN)

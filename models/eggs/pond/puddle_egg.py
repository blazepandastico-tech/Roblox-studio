"""Puddle Egg: Lily Pond · Common egg. Splish, splash, hatch."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="puddle_egg",
    name="Puddle Egg",
    biome="pond",
    rarity="common",
    base="light_blue",
    accent="sky",
    accent2="white",
    accent3="black",
    patterns=[
        ("wave", {"at": 0.4, "amp": 1.0, "freq": 3, "width": 1, "color": "sky"}),
        ("bottom", {"to": 0.14, "color": "blue"}),
    ],
    extras=[],
    flavor="Splish, splash, hatch.",
)


def build():
    return build_egg(DESIGN)

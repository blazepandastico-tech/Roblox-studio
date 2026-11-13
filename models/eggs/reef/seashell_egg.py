"""Seashell Egg: Coral Reef · Uncommon egg. Hold it to your ear and hear the sea."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="seashell_egg",
    name="Seashell Egg",
    biome="reef",
    rarity="uncommon",
    base="peach",
    accent="coral",
    accent2="white",
    accent3="black",
    patterns=[("stripes", {"count": 8, "color": "coral", "y": (0.15, 1.0)})],
    extras=[],
    flavor="Hold it to your ear and hear the sea.",
)


def build():
    return build_egg(DESIGN)

"""Bubble Egg: Coral Reef · Common egg. Pop! Pop! Pop!"""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="bubble_egg",
    name="Bubble Egg",
    biome="reef",
    rarity="common",
    base="light_blue",
    accent="white",
    accent2="white",
    accent3="black",
    patterns=[("dots", {"rows": (0.3, 0.55, 0.8), "count": 6, "color": "white"})],
    extras=["bubbles"],
    flavor="Pop! Pop! Pop!",
)


def build():
    return build_egg(DESIGN)

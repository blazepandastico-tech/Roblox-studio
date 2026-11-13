"""Cactus Egg: Sunbaked Dunes · Uncommon egg. Prickly outside, soft inside."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="cactus_egg",
    name="Cactus Egg",
    biome="dunes",
    rarity="uncommon",
    base="green",
    accent="dark_green",
    accent2="white",
    accent3="black",
    patterns=[("stripes", {"count": 6, "color": "dark_green", "y": (0.05, 0.95)})],
    extras=[("cactus_arms", {"color": "green", "flower": "hot_pink"})],
    flavor="Prickly outside, soft inside.",
)


def build():
    return build_egg(DESIGN)

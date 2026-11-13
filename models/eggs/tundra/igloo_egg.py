"""Igloo Egg: Frostpeak Tundra · Legendary egg. A cosy little ice house."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="igloo_egg",
    name="Igloo Egg",
    biome="tundra",
    rarity="legendary",
    base="snow",
    accent="light_gray",
    accent2="white",
    accent3="black",
    patterns=[("panels", {"color": "light_gray", "count": 8, "rows": (0.3, 0.55, 0.8)})],
    extras=[("snowcap", {"color": "white"})],
    flavor="A cosy little ice house.",
)


def build():
    return build_egg(DESIGN)

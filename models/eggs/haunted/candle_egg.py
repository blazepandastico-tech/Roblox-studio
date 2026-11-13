"""Candle Egg: Haunted Hollow · Uncommon egg. Never let the flame go out."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="candle_egg",
    name="Candle Egg",
    biome="haunted",
    rarity="uncommon",
    base="lavender",
    accent="white",
    accent2="white",
    accent3="black",
    patterns=[("drips", {"from": 0.8, "color": "white", "count": 6, "max_len": 3})],
    extras=[("candle", {"wax": "cream", "flame": "fire"})],
    flavor="Never let the flame go out.",
)


def build():
    return build_egg(DESIGN)

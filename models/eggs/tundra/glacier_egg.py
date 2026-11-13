"""Glacier Egg: Frostpeak Tundra · Mythic egg. Frozen since the last ice age."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="glacier_egg",
    name="Glacier Egg",
    biome="tundra",
    rarity="mythic",
    base=("#BDEBFF", "glass"),
    accent="sky",
    accent2="white",
    accent3="black",
    patterns=[],
    extras=[("inner", {"color": "sky", "shape": "gem"}), ("crystals", {"color": "ice", "count": 6})],
    flavor="Frozen since the last ice age.",
)


def build():
    return build_egg(DESIGN)

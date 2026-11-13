"""Frosty Egg: Frostpeak Tundra · Uncommon egg. Wearing a fresh snow hat."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="frosty_egg",
    name="Frosty Egg",
    biome="tundra",
    rarity="uncommon",
    base="light_blue",
    accent="snow",
    accent2="white",
    accent3="black",
    patterns=[],
    extras=[("snowcap", {"color": "snow"})],
    flavor="Wearing a fresh snow hat.",
)


def build():
    return build_egg(DESIGN)

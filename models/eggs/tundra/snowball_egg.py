"""Snowball Egg: Frostpeak Tundra · Common egg. Do not throw it. Please."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="snowball_egg",
    name="Snowball Egg",
    biome="tundra",
    rarity="common",
    base="snow",
    accent="light_blue",
    accent2="white",
    accent3="black",
    patterns=[("speckle", {"colors": {"light_blue": 1}, "fraction": 0.15, "seed": 1})],
    extras=[],
    flavor="Do not throw it. Please.",
)


def build():
    return build_egg(DESIGN)

"""Ash Egg: Ember Caldera · Common egg. Dusty, but surprisingly warm."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="ash_egg",
    name="Ash Egg",
    biome="caldera",
    rarity="common",
    base="gray",
    accent="dark_gray",
    accent2="white",
    accent3="black",
    patterns=[("speckle", {"colors": {"dark_gray": 2, "charcoal": 1}, "fraction": 0.4, "seed": 3})],
    extras=[],
    flavor="Dusty, but surprisingly warm.",
)


def build():
    return build_egg(DESIGN)

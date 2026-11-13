"""Stardust Egg: Starlight Rim · Common egg. Sprinkled with the dust of stars."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="stardust_egg",
    name="Stardust Egg",
    biome="starlight",
    rarity="common",
    base="dark_blue",
    accent="white",
    accent2="white",
    accent3="black",
    patterns=[("speckle", {"colors": {"white": 1}, "fraction": 0.1, "seed": 2})],
    extras=[],
    flavor="Sprinkled with the dust of stars.",
)


def build():
    return build_egg(DESIGN)

"""Fossil Egg: Fossil Valley · Common egg. Dug up from very old dirt."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="fossil_egg",
    name="Fossil Egg",
    biome="fossil",
    rarity="common",
    base="tan",
    accent="dark_brown",
    accent2="white",
    accent3="black",
    patterns=[],
    extras=[("fossil", {"color": "dark_brown", "at": 0.6})],
    flavor="Dug up from very old dirt.",
)


def build():
    return build_egg(DESIGN)

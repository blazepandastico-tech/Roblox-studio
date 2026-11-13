"""Obsidian Egg: Ember Caldera · Celestial egg. Sharp, dark and shiny as glass."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="obsidian_egg",
    name="Obsidian Egg",
    biome="caldera",
    rarity="celestial",
    base="black",
    accent="neon_purple",
    accent2="white",
    accent3="black",
    patterns=[("speckle", {"colors": {"neon_purple": 1}, "fraction": 0.05, "seed": 5})],
    extras=[("crystals", {"color": ("#7A3FD6", "glass"), "count": 6})],
    flavor="Sharp, dark and shiny as glass.",
)


def build():
    return build_egg(DESIGN)

"""Amber Egg: Fossil Valley · Mythic egg. A bug from long ago, trapped in honey-coloured stone."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="amber_egg",
    name="Amber Egg",
    biome="fossil",
    rarity="mythic",
    base=("#FFAA33", "glass"),
    accent="dark_brown",
    accent2="white",
    accent3="black",
    patterns=[],
    extras=[("inner", {"color": "dark_brown", "shape": "bug"})],
    flavor="A bug from long ago, trapped in honey-coloured stone.",
)


def build():
    return build_egg(DESIGN)

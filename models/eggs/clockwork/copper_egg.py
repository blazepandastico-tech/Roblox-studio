"""Copper Egg: Clockwork Works · Uncommon egg. Shiny now. Green later."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="copper_egg",
    name="Copper Egg",
    biome="clockwork",
    rarity="uncommon",
    base="copper",
    accent="bronze",
    accent2="white",
    accent3="black",
    patterns=[("bands", {"at": (0.3, 0.7), "width": 1, "color": "bronze"})],
    extras=[("rivets", {"color": "gunmetal", "rows": (0.3, 0.7), "count": 10})],
    flavor="Shiny now. Green later.",
)


def build():
    return build_egg(DESIGN)

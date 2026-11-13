"""Dawnstone Egg: Fossil Valley · Divine egg. From the dawn of time."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="dawnstone_egg",
    name="Dawnstone Egg",
    biome="fossil",
    rarity="divine",
    base="peach",
    accent="gold",
    accent2="white",
    accent3="black",
    patterns=[("gradient", {"stops": ((0.6, "light_yellow"),)})],
    extras=[("horns", {"color": "gold", "tip": "white"}), ("wings", {"color": "white", "tip": "peach"})],
    flavor="From the dawn of time.",
)


def build():
    return build_egg(DESIGN)

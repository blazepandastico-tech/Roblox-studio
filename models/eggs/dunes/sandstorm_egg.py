"""Sandstorm Egg: Sunbaked Dunes · Secret egg. Something hides inside the storm."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="sandstorm_egg",
    name="Sandstorm Egg",
    biome="dunes",
    rarity="secret",
    base="tan",
    accent="dark_orange",
    accent2="white",
    accent3="black",
    patterns=[("swirl", {"count": 3, "twist": 6.0, "color": "light_brown"})],
    extras=[("eyes_peek", {"color": "neon_red", "at": 0.62})],
    flavor="Something hides inside the storm.",
)


def build():
    return build_egg(DESIGN)

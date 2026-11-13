"""Tiki Egg: Vine Jungle · Epic egg. Carved by the jungle spirits."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="tiki_egg",
    name="Tiki Egg",
    biome="jungle",
    rarity="epic",
    base="light_brown",
    accent="dark_brown",
    accent2="white",
    accent3="black",
    patterns=[("bands", {"at": (0.18, 0.85), "width": 1, "color": "dark_brown"})],
    extras=[("tiki", {}), ("leaf_crown", {"color": "green", "count": 5})],
    flavor="Carved by the jungle spirits.",
)


def build():
    return build_egg(DESIGN)

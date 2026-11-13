"""Chocolate Egg: Sugar Isles · Mythic egg. Someone already took a bite..."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="chocolate_egg",
    name="Chocolate Egg",
    biome="candy",
    rarity="mythic",
    base="brown",
    accent="dark_brown",
    accent2="white",
    accent3="black",
    patterns=[("checker", {"count": 6, "rows": 3, "color": "dark_brown"})],
    extras=[("bite", {"filling": "cream"})],
    flavor="Someone already took a bite...",
)


def build():
    return build_egg(DESIGN)

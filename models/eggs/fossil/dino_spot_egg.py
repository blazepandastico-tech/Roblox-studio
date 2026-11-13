"""Dino Spot Egg: Fossil Valley · Uncommon egg. Spotty like a baby dinosaur."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="dino_spot_egg",
    name="Dino Spot Egg",
    biome="fossil",
    rarity="uncommon",
    base="light_green",
    accent="green",
    accent2="white",
    accent3="black",
    patterns=[("spots", {"count": 8, "size": 1.0, "color": "green", "seed": 5})],
    extras=[],
    flavor="Spotty like a baby dinosaur.",
)


def build():
    return build_egg(DESIGN)

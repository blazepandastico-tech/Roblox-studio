"""Venom Egg: Vine Jungle · Mythic egg. Bright colours mean: do not touch!"""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="venom_egg",
    name="Venom Egg",
    biome="jungle",
    rarity="mythic",
    base="lime",
    accent="dark_blue",
    accent2="white",
    accent3="black",
    patterns=[
        ("spots", {"count": 8, "size": 1.0, "color": "dark_blue", "seed": 11}),
        ("cracks", {"count": 3, "length": 7, "color": "neon_green", "seed": 2}),
    ],
    extras=[],
    flavor="Bright colours mean: do not touch!",
    glow=("#6BFF5E", "glow"),
)


def build():
    return build_egg(DESIGN)

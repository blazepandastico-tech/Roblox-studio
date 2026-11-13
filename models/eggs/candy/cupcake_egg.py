"""Cupcake Egg: Sugar Isles · Epic egg. Topped with a cherry, of course."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="cupcake_egg",
    name="Cupcake Egg",
    biome="candy",
    rarity="epic",
    base="peach",
    accent="pink",
    accent2="white",
    accent3="black",
    patterns=[
        ("stripes", {"count": 10, "color": "light_brown", "y": (0.0, 0.35)}),
        ("drips", {"from": 0.55, "color": "pink", "count": 8, "max_len": 2}),
    ],
    extras=[("cherry", {"color": "red", "stem": "green"})],
    flavor="Topped with a cherry, of course.",
)


def build():
    return build_egg(DESIGN)

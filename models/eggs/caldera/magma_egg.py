"""Magma Egg: Ember Caldera · Epic egg. Hot enough to cook breakfast."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="magma_egg",
    name="Magma Egg",
    biome="caldera",
    rarity="epic",
    base="charcoal",
    accent="lava",
    accent2="white",
    accent3="black",
    patterns=[
        ("cracks", {"count": 5, "length": 9, "color": "lava", "seed": 3}),
        ("bottom", {"to": 0.18, "color": "dark_stone"}),
    ],
    extras=[],
    flavor="Hot enough to cook breakfast.",
)


def build():
    return build_egg(DESIGN)

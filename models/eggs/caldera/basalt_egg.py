"""Basalt Egg: Ember Caldera · Rare egg. Cooled lava, stacked in columns."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="basalt_egg",
    name="Basalt Egg",
    biome="caldera",
    rarity="rare",
    base="dark_stone",
    accent="slate",
    accent2="white",
    accent3="black",
    patterns=[
        ("stripes", {"count": 6, "color": "slate", "y": (0.0, 1.0)}),
        ("bands", {"at": (0.33, 0.66), "width": 1, "color": "charcoal"}),
    ],
    extras=[],
    flavor="Cooled lava, stacked in columns.",
)


def build():
    return build_egg(DESIGN)

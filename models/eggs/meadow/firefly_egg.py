"""Firefly Egg: Clover Meadow · Celestial egg. Glows softly when the meadow goes dark."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="firefly_egg",
    name="Firefly Egg",
    biome="meadow",
    rarity="celestial",
    base="forest",
    accent="lime",
    accent2="white",
    accent3="black",
    patterns=[
        ("speckle", {"colors": {"neon_yellow": 1}, "fraction": 0.09, "seed": 12}),
        ("bottom", {"to": 0.2, "color": "dark_green"}),
    ],
    extras=[("sparkles", {"color": "neon_yellow"})],
    flavor="Glows softly when the meadow goes dark.",
    glow=("#FFF24A", "glow"),
)


def build():
    return build_egg(DESIGN)

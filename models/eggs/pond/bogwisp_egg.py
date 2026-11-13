"""Bogwisp Egg: Lily Pond · Celestial egg. Follow the lights... if you dare."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="bogwisp_egg",
    name="Bogwisp Egg",
    biome="pond",
    rarity="celestial",
    base="dark_teal",
    accent="neon_green",
    accent2="white",
    accent3="black",
    patterns=[
        ("speckle", {"colors": {"neon_green": 1}, "fraction": 0.07, "seed": 14}),
        ("bottom", {"to": 0.2, "color": "forest"}),
    ],
    extras=[("sparkles", {"color": "neon_green"})],
    flavor="Follow the lights... if you dare.",
    glow=("#6BFF5E", "glow"),
)


def build():
    return build_egg(DESIGN)

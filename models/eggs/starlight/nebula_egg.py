"""Nebula Egg: Starlight Rim · Mythic egg. A whole star nursery in one shell."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="nebula_egg",
    name="Nebula Egg",
    biome="starlight",
    rarity="mythic",
    base="dark_purple",
    accent="violet",
    accent2="white",
    accent3="black",
    patterns=[
        ("swirl", {"count": 2, "twist": 9.0, "color": "violet"}),
        ("speckle", {"colors": {"neon_pink": 1}, "fraction": 0.06, "seed": 3}),
    ],
    extras=[],
    flavor="A whole star nursery in one shell.",
)


def build():
    return build_egg(DESIGN)

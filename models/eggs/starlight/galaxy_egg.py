"""Galaxy Egg: Starlight Rim · Celestial egg. Billions of stars, one egg."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="galaxy_egg",
    name="Galaxy Egg",
    biome="starlight",
    rarity="celestial",
    base="navy",
    accent="purple",
    accent2="white",
    accent3="black",
    patterns=[
        ("swirl", {"count": 3, "twist": 8.0, "color": "purple"}),
        ("speckle", {"colors": {"white": 2, "neon_cyan": 1}, "fraction": 0.08, "seed": 8}),
    ],
    extras=[("orbit", {"color": "neon_cyan", "count": 4})],
    flavor="Billions of stars, one egg.",
)


def build():
    return build_egg(DESIGN)

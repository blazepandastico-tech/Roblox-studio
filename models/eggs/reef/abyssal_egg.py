"""Abyssal Egg: Coral Reef · Celestial egg. From where sunlight never reaches."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="abyssal_egg",
    name="Abyssal Egg",
    biome="reef",
    rarity="celestial",
    base="navy",
    accent="neon_cyan",
    accent2="white",
    accent3="black",
    patterns=[("speckle", {"colors": {"neon_cyan": 1}, "fraction": 0.07, "seed": 7})],
    extras=[("orbit", {"color": "neon_cyan", "count": 3})],
    flavor="From where sunlight never reaches.",
)


def build():
    return build_egg(DESIGN)

"""Mirage Egg: Sunbaked Dunes · Celestial egg. Is it really there? Touch it and see."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="mirage_egg",
    name="Mirage Egg",
    biome="dunes",
    rarity="celestial",
    base=("#FFD9A0", "glass"),
    accent="light",
    accent2="white",
    accent3="black",
    patterns=[("speckle", {"colors": {"light_yellow": 1}, "fraction": 0.05, "seed": 4})],
    extras=[("orbit", {"color": "neon_yellow", "count": 3})],
    flavor="Is it really there? Touch it and see.",
)


def build():
    return build_egg(DESIGN)

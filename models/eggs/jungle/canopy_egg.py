"""Canopy Egg: Vine Jungle · Celestial egg. Born in the treetops."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="canopy_egg",
    name="Canopy Egg",
    biome="jungle",
    rarity="celestial",
    base="forest",
    accent="lime",
    accent2="white",
    accent3="black",
    patterns=[("speckle", {"colors": {"lime": 2, "green": 1}, "fraction": 0.2, "seed": 7})],
    extras=[("leaf_crown", {"color": "lime", "count": 7}), ("sparkles", {"color": "neon_green"})],
    flavor="Born in the treetops.",
)


def build():
    return build_egg(DESIGN)

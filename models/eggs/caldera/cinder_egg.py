"""Cinder Egg: Ember Caldera · Uncommon egg. Little embers still glow on it."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="cinder_egg",
    name="Cinder Egg",
    biome="caldera",
    rarity="uncommon",
    base="charcoal",
    accent="orange",
    accent2="white",
    accent3="black",
    patterns=[("speckle", {"colors": {"orange": 1, "fire": 1}, "fraction": 0.1, "seed": 4})],
    extras=[],
    flavor="Little embers still glow on it.",
)


def build():
    return build_egg(DESIGN)

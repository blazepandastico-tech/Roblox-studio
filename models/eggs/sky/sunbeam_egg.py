"""Sunbeam Egg: Sky Citadel · Legendary egg. Made of pure morning light."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="sunbeam_egg",
    name="Sunbeam Egg",
    biome="sky",
    rarity="legendary",
    base="light_yellow",
    accent="gold",
    accent2="white",
    accent3="black",
    patterns=[("gradient", {"stops": ((0.6, "yellow"),)})],
    extras=[("rays", {"color": "neon_yellow"})],
    flavor="Made of pure morning light.",
)


def build():
    return build_egg(DESIGN)

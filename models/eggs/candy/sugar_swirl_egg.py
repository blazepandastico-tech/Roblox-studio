"""Sugar Swirl Egg: Sugar Isles · Celestial egg. Mint and berry, swirled together."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="sugar_swirl_egg",
    name="Sugar Swirl Egg",
    biome="candy",
    rarity="celestial",
    base="lavender",
    accent="mint",
    accent2="white",
    accent3="black",
    patterns=[("swirl", {"count": 2, "twist": 7.0, "color": "mint"})],
    extras=[("sparkles", {"color": "neon_pink"})],
    flavor="Mint and berry, swirled together.",
)


def build():
    return build_egg(DESIGN)

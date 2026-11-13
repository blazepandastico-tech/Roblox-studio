"""Thunder Egg: Sky Citadel · Mythic egg. Rumbles before it hatches."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="thunder_egg",
    name="Thunder Egg",
    biome="sky",
    rarity="mythic",
    base="dark_gray",
    accent="neon_yellow",
    accent2="white",
    accent3="black",
    patterns=[],
    extras=[
        ("thunder_cloud", {"color": "charcoal", "bolt": "neon_yellow"}),
        ("lightning", {"color": "neon_yellow", "at": 0.7}),
    ],
    flavor="Rumbles before it hatches.",
)


def build():
    return build_egg(DESIGN)

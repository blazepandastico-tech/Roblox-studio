"""Polar Crown Egg: Frostpeak Tundra · Divine egg. Royalty of the frozen north."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="polar_crown_egg",
    name="Polar Crown Egg",
    biome="tundra",
    rarity="divine",
    base="white",
    accent="light_blue",
    accent2="white",
    accent3="black",
    patterns=[("zigzag", {"at": 0.42, "teeth": 10, "width": 1, "color": "light_blue"})],
    extras=[
        ("crown", {"color": "silver", "gem": "neon_cyan"}),
        ("wings", {"color": "white", "tip": "light_blue"}),
    ],
    flavor="Royalty of the frozen north.",
)


def build():
    return build_egg(DESIGN)

"""Heavenly Egg: Sky Citadel · Divine egg. The rarest egg above the clouds."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="heavenly_egg",
    name="Heavenly Egg",
    biome="sky",
    rarity="divine",
    base="white",
    accent="gold",
    accent2="white",
    accent3="black",
    patterns=[
        ("gradient", {"stops": ((0.55, "light_yellow"),)}),
        ("zigzag", {"at": 0.35, "teeth": 10, "width": 1, "color": "gold"}),
    ],
    extras=[
        ("crown", {"color": "gold", "gem": "neon_cyan"}),
        ("sun_disk", {"color": "glow"}),
        ("wings", {"color": "white", "tip": "gold"}),
    ],
    flavor="The rarest egg above the clouds.",
)


def build():
    return build_egg(DESIGN)

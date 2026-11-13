"""Aurora Egg: Frostpeak Tundra · Celestial egg. The northern lights, folded into an egg."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="aurora_egg",
    name="Aurora Egg",
    biome="tundra",
    rarity="celestial",
    base="navy",
    accent="teal",
    accent2="white",
    accent3="black",
    patterns=[
        ("wave", {"at": 0.55, "amp": 1.2, "freq": 3, "width": 1, "color": "neon_green"}),
        ("wave", {"at": 0.68, "amp": 1.2, "freq": 3, "width": 1, "color": "neon_purple"}),
        ("speckle", {"colors": {"white": 1}, "fraction": 0.04, "seed": 8}),
    ],
    extras=[("sparkles", {"color": "neon_green"})],
    flavor="The northern lights, folded into an egg.",
)


def build():
    return build_egg(DESIGN)

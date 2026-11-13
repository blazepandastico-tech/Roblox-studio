"""Moonpool Egg: Lily Pond · Mythic egg. Reflects a moon that is not there."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="moonpool_egg",
    name="Moonpool Egg",
    biome="pond",
    rarity="mythic",
    base="navy",
    accent="dark_blue",
    accent2="white",
    accent3="black",
    patterns=[
        ("gradient", {"stops": ((0.55, "dark_blue"),)}),
        ("speckle", {"colors": {"white": 1}, "fraction": 0.06, "seed": 9}),
    ],
    extras=[("moon", {"color": "light_yellow"})],
    flavor="Reflects a moon that is not there.",
)


def build():
    return build_egg(DESIGN)

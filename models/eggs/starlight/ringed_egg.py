"""Ringed Egg: Starlight Rim · Epic egg. A tiny planet with a tiny ring."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="ringed_egg",
    name="Ringed Egg",
    biome="starlight",
    rarity="epic",
    base="orange",
    accent="tan",
    accent2="white",
    accent3="black",
    patterns=[("bands", {"at": (0.35, 0.6), "width": 1, "color": "tan"})],
    extras=[("planet_ring", {"color": "sand", "color2": "light_brown"})],
    flavor="A tiny planet with a tiny ring.",
)


def build():
    return build_egg(DESIGN)

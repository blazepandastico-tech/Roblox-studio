"""Batwing Egg: Haunted Hollow · Epic egg. Hangs upside down to sleep."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="batwing_egg",
    name="Batwing Egg",
    biome="haunted",
    rarity="epic",
    base="charcoal",
    accent="black",
    accent2="white",
    accent3="black",
    patterns=[("face", {"style": ["Y...Y"], "at": 0.62, "colors": {"Y": "neon_yellow"}})],
    extras=[("bat_wings", {"color": "black"})],
    flavor="Hangs upside down to sleep.",
)


def build():
    return build_egg(DESIGN)

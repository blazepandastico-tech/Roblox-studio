"""Scarab Egg: Sunbaked Dunes · Epic egg. A lucky beetle guards the shell."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="scarab_egg",
    name="Scarab Egg",
    biome="dunes",
    rarity="epic",
    base="sand",
    accent="teal",
    accent2="white",
    accent3="black",
    patterns=[("bands", {"at": (0.22, 0.82), "width": 1, "color": "gold"})],
    extras=[("scarab", {"color": "teal", "at": 0.55})],
    flavor="A lucky beetle guards the shell.",
)


def build():
    return build_egg(DESIGN)

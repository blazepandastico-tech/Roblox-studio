"""Sandy Egg: Sunbaked Dunes · Common egg. Still warm from the desert sun."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="sandy_egg",
    name="Sandy Egg",
    biome="dunes",
    rarity="common",
    base="sand",
    accent="tan",
    accent2="white",
    accent3="black",
    patterns=[("speckle", {"colors": {"tan": 2, "light_brown": 1}, "fraction": 0.3, "seed": 2})],
    extras=[],
    flavor="Still warm from the desert sun.",
)


def build():
    return build_egg(DESIGN)

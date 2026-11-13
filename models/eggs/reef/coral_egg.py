"""Coral Egg: Coral Reef · Epic egg. Grown slowly on the reef."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="coral_egg",
    name="Coral Egg",
    biome="reef",
    rarity="epic",
    base="hot_pink",
    accent="coral",
    accent2="white",
    accent3="black",
    patterns=[("speckle", {"colors": {"coral": 2, "pink": 1}, "fraction": 0.3, "seed": 6})],
    extras=[("coral", {"color": "coral", "color2": "hot_pink"})],
    flavor="Grown slowly on the reef.",
)


def build():
    return build_egg(DESIGN)

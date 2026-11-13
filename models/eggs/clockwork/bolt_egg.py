"""Bolt Egg: Clockwork Works · Common egg. Held together with plenty of bolts."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="bolt_egg",
    name="Bolt Egg",
    biome="clockwork",
    rarity="common",
    base="steel",
    accent="gunmetal",
    accent2="white",
    accent3="black",
    patterns=[],
    extras=[("rivets", {"color": "gunmetal", "rows": (0.25, 0.5, 0.75), "count": 8})],
    flavor="Held together with plenty of bolts.",
)


def build():
    return build_egg(DESIGN)

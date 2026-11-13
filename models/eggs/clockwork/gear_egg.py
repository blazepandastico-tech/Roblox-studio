"""Gear Egg: Clockwork Works · Rare egg. Tick, tock, crack."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="gear_egg",
    name="Gear Egg",
    biome="clockwork",
    rarity="rare",
    base="bronze",
    accent="copper",
    accent2="white",
    accent3="black",
    patterns=[("bottom", {"to": 0.15, "color": "gunmetal"})],
    extras=[("gear", {"color": "copper", "at": 0.5})],
    flavor="Tick, tock, crack.",
)


def build():
    return build_egg(DESIGN)

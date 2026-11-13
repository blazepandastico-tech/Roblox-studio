"""Kite Egg: Sky Citadel · Epic egg. Flies highest on windy days."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="kite_egg",
    name="Kite Egg",
    biome="sky",
    rarity="epic",
    base="yellow",
    accent="red",
    accent2="white",
    accent3="black",
    patterns=[("diamonds", {"count": 4, "rows": 4.0, "color": "red"})],
    extras=[("bow", {"color": "red", "knot": "blue"})],
    flavor="Flies highest on windy days.",
)


def build():
    return build_egg(DESIGN)

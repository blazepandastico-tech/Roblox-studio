"""Spiky Egg: Fossil Valley · Epic egg. Do not hug."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="spiky_egg",
    name="Spiky Egg",
    biome="fossil",
    rarity="epic",
    base="green",
    accent="cream",
    accent2="white",
    accent3="black",
    patterns=[("bottom", {"to": 0.2, "color": "dark_green"})],
    extras=[("ridge", {"color": "cream"})],
    flavor="Do not hug.",
)


def build():
    return build_egg(DESIGN)

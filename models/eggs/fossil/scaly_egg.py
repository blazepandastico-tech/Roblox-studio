"""Scaly Egg: Fossil Valley · Rare egg. Tough scales, tougher baby."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="scaly_egg",
    name="Scaly Egg",
    biome="fossil",
    rarity="rare",
    base="olive",
    accent="moss",
    accent2="white",
    accent3="black",
    patterns=[("scales", {"count": 10, "color": "moss"})],
    extras=[],
    flavor="Tough scales, tougher baby.",
)


def build():
    return build_egg(DESIGN)

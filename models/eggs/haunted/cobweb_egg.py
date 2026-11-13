"""Cobweb Egg: Haunted Hollow · Rare egg. The spiders moved in first."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="cobweb_egg",
    name="Cobweb Egg",
    biome="haunted",
    rarity="rare",
    base="dark_gray",
    accent="white",
    accent2="white",
    accent3="black",
    patterns=[("web", {"color": "light_gray", "lines": 6, "from": 0.4})],
    extras=[],
    flavor="The spiders moved in first.",
)


def build():
    return build_egg(DESIGN)

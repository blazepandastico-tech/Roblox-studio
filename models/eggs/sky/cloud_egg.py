"""Cloud Egg: Sky Citadel · Common egg. Light as air."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="cloud_egg",
    name="Cloud Egg",
    biome="sky",
    rarity="common",
    base="white",
    accent="light_blue",
    accent2="white",
    accent3="black",
    patterns=[],
    extras=[("clouds", {"color": "white"})],
    flavor="Light as air.",
)


def build():
    return build_egg(DESIGN)

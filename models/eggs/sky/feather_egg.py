"""Feather Egg: Sky Citadel · Rare egg. Tickles a little."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="feather_egg",
    name="Feather Egg",
    biome="sky",
    rarity="rare",
    base="sky",
    accent="white",
    accent2="white",
    accent3="black",
    patterns=[],
    extras=[("feather", {"color": "white", "tip": "gold"})],
    flavor="Tickles a little.",
)


def build():
    return build_egg(DESIGN)

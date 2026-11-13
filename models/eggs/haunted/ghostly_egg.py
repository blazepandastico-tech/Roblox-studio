"""Ghostly Egg: Haunted Hollow · Legendary egg. Boo! Did it scare you?"""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="ghostly_egg",
    name="Ghostly Egg",
    biome="haunted",
    rarity="legendary",
    base="white",
    accent="light_blue",
    accent2="white",
    accent3="black",
    patterns=[("face", {"style": "dots", "at": 0.6})],
    extras=[("ghost", {"color": "white"})],
    flavor="Boo! Did it scare you?",
)


def build():
    return build_egg(DESIGN)

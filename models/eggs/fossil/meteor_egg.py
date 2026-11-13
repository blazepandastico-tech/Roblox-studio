"""Meteor Egg: Fossil Valley · Celestial egg. It fell from the sky and landed here."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="meteor_egg",
    name="Meteor Egg",
    biome="fossil",
    rarity="celestial",
    base="dark_stone",
    accent="fire",
    accent2="white",
    accent3="black",
    patterns=[("cracks", {"count": 4, "length": 8, "color": "fire", "seed": 6})],
    extras=[("comet_tail", {"colors": ("light", "fire", "orange")})],
    flavor="It fell from the sky and landed here.",
)


def build():
    return build_egg(DESIGN)

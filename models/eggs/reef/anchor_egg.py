"""Anchor Egg: Coral Reef · Legendary egg. Sails the seven seas."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="anchor_egg",
    name="Anchor Egg",
    biome="reef",
    rarity="legendary",
    base="navy",
    accent="white",
    accent2="white",
    accent3="black",
    patterns=[("bands", {"at": (0.25, 0.75), "width": 2, "color": "white"})],
    extras=[("anchor", {"color": "gold", "at": 0.62})],
    flavor="Sails the seven seas.",
)


def build():
    return build_egg(DESIGN)

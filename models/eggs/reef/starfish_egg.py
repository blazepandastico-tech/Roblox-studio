"""Starfish Egg: Coral Reef · Rare egg. A starfish stuck on for the ride."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="starfish_egg",
    name="Starfish Egg",
    biome="reef",
    rarity="rare",
    base="sky",
    accent="orange",
    accent2="white",
    accent3="black",
    patterns=[("bottom", {"to": 0.15, "color": "sand"})],
    extras=[("starfish", {"color": "orange", "at": 0.55})],
    flavor="A starfish stuck on for the ride.",
)


def build():
    return build_egg(DESIGN)

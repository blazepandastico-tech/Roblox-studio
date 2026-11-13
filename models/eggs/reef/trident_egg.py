"""Trident Egg: Coral Reef · Divine egg. Commands the tides."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="trident_egg",
    name="Trident Egg",
    biome="reef",
    rarity="divine",
    base="teal",
    accent="gold",
    accent2="white",
    accent3="black",
    patterns=[("wave", {"at": 0.5, "amp": 1.0, "freq": 4, "width": 1, "color": "gold"})],
    extras=[("trident", {"color": "gold"}), ("wings", {"color": "white", "tip": "sky"})],
    flavor="Commands the tides.",
)


def build():
    return build_egg(DESIGN)

"""Tidecrown Egg: Lily Pond · Divine egg. Ruler of every ripple in the pond."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="tidecrown_egg",
    name="Tidecrown Egg",
    biome="pond",
    rarity="divine",
    base="light_blue",
    accent="gold",
    accent2="white",
    accent3="black",
    patterns=[
        ("wave", {"at": 0.35, "amp": 1.0, "freq": 4, "width": 1, "color": "gold"}),
        ("wave", {"at": 0.6, "amp": 1.0, "freq": 4, "width": 1, "color": "white"}),
    ],
    extras=[("crown", {"color": "gold", "gem": "neon_cyan"}), ("wings", {"color": "white", "tip": "sky"})],
    flavor="Ruler of every ripple in the pond.",
)


def build():
    return build_egg(DESIGN)

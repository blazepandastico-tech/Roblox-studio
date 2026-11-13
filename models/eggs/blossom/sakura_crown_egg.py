"""Sakura Crown Egg: Blossom Hills · Divine egg. Crowned in eternal spring."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="sakura_crown_egg",
    name="Sakura Crown Egg",
    biome="blossom",
    rarity="divine",
    base="blush",
    accent="pink",
    accent2="white",
    accent3="black",
    patterns=[("zigzag", {"at": 0.4, "teeth": 10, "width": 1, "color": "white"})],
    extras=[
        ("crown", {"color": "gold", "gem": "hot_pink"}),
        ("petals", {"color": "pink", "color2": "white"}),
        ("wings", {"color": "white", "tip": "pink"}),
    ],
    flavor="Crowned in eternal spring.",
)


def build():
    return build_egg(DESIGN)

"""Toadstool Egg: Clover Meadow · Mythic egg. Half egg, half mushroom, all cute."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="toadstool_egg",
    name="Toadstool Egg",
    biome="meadow",
    rarity="mythic",
    base="cream",
    accent="red",
    accent2="white",
    accent3="black",
    patterns=[
        ("cap", {"from": 0.5, "color": "red"}),
        ("spots", {"count": 6, "size": 0.9, "color": "white", "seed": 8, "y": (0.55, 0.95)}),
        ("face", {"style": "cute_small", "at": 0.3}),
    ],
    extras=[],
    flavor="Half egg, half mushroom, all cute.",
)


def build():
    return build_egg(DESIGN)

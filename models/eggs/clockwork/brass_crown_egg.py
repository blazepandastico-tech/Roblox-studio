"""Brass Crown Egg: Clockwork Works · Divine egg. The masterpiece of the Clockwork Works."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="brass_crown_egg",
    name="Brass Crown Egg",
    biome="clockwork",
    rarity="divine",
    base=("#D9A441", "metal"),
    accent="gold",
    accent2="white",
    accent3="black",
    patterns=[("panels", {"color": "bronze", "count": 8, "rows": (0.35,)})],
    extras=[
        ("gear", {"color": "gold", "at": 0.5}),
        ("crown", {"color": "gold", "gem": "neon_cyan"}),
        ("wings", {"color": "light_yellow", "tip": "copper"}),
    ],
    flavor="The masterpiece of the Clockwork Works.",
)


def build():
    return build_egg(DESIGN)

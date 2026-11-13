"""Starcrown Egg: Starlight Rim · Divine egg. Every star bows to it."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="starcrown_egg",
    name="Starcrown Egg",
    biome="starlight",
    rarity="divine",
    base="navy",
    accent="neon_yellow",
    accent2="white",
    accent3="black",
    patterns=[("speckle", {"colors": {"neon_yellow": 1}, "fraction": 0.08, "seed": 6})],
    extras=[
        ("crown", {"color": "gold", "gem": "neon_cyan"}),
        ("wings", {"color": "white", "tip": "neon_cyan"}),
    ],
    flavor="Every star bows to it.",
)


def build():
    return build_egg(DESIGN)

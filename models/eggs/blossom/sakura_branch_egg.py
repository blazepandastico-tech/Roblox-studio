"""Sakura Branch Egg: Blossom Hills · Legendary egg. Blossoms bloom along the branches."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="sakura_branch_egg",
    name="Sakura Branch Egg",
    biome="blossom",
    rarity="legendary",
    base="cream",
    accent="dark_brown",
    accent2="white",
    accent3="black",
    patterns=[
        ("vines", {"color": "dark_brown", "turns": 2, "twist": 9.0, "leaf": "pink"}),
        ("spots", {"count": 6, "size": 0.6, "color": "pink", "seed": 3}),
    ],
    extras=[],
    flavor="Blossoms bloom along the branches.",
)


def build():
    return build_egg(DESIGN)

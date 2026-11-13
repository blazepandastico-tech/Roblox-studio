"""Sprinkle Egg: Sugar Isles · Uncommon egg. Frosted and sprinkled like a donut."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="sprinkle_egg",
    name="Sprinkle Egg",
    biome="candy",
    rarity="uncommon",
    base="cream",
    accent="pink",
    accent2="white",
    accent3="black",
    patterns=[
        ("drips", {"from": 0.62, "color": "pink", "count": 7, "max_len": 2}),
        (
            "speckle",
            {
                "colors": {"red": 1, "lime": 1, "sky": 1, "yellow": 1},
                "fraction": 0.18,
                "seed": 4,
                "only": ["pink"],
            },
        ),
    ],
    extras=[],
    flavor="Frosted and sprinkled like a donut.",
)


def build():
    return build_egg(DESIGN)

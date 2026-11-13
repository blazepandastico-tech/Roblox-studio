"""Sour Egg: Sugar Isles · Secret egg. Grumpy and very, very sour."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="sour_egg",
    name="Sour Egg",
    biome="candy",
    rarity="secret",
    base="lime",
    accent="white",
    accent2="white",
    accent3="black",
    patterns=[
        ("speckle", {"colors": {"white": 1}, "fraction": 0.3, "seed": 3}),
        ("face", {"style": "angry", "at": 0.58}),
    ],
    extras=[],
    flavor="Grumpy and very, very sour.",
)


def build():
    return build_egg(DESIGN)

"""Oasis Egg: Sunbaked Dunes · Legendary egg. A drop of shade in the dunes."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="oasis_egg",
    name="Oasis Egg",
    biome="dunes",
    rarity="legendary",
    base="sky",
    accent="blue",
    accent2="white",
    accent3="black",
    patterns=[
        ("bottom", {"to": 0.3, "color": "sand"}),
        ("wave", {"at": 0.42, "amp": 0.8, "freq": 3, "width": 1, "color": "blue"}),
    ],
    extras=[("palm", {"trunk": "light_brown", "leaf": "green"})],
    flavor="A drop of shade in the dunes.",
)


def build():
    return build_egg(DESIGN)

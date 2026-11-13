"""Parrot Feather Egg: Vine Jungle · Legendary egg. Loud colours for a loud bird."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="parrot_feather_egg",
    name="Parrot Feather Egg",
    biome="jungle",
    rarity="legendary",
    base="red",
    accent="yellow",
    accent2="white",
    accent3="black",
    patterns=[
        ("band", {"at": 0.45, "width": 2, "color": "yellow"}),
        ("band", {"at": 0.62, "width": 2, "color": "blue"}),
    ],
    extras=[("feather", {"color": "blue", "tip": "yellow"})],
    flavor="Loud colours for a loud bird.",
)


def build():
    return build_egg(DESIGN)

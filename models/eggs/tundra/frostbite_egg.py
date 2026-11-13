"""Frostbite Egg: Frostpeak Tundra · Secret egg. It bites back."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="frostbite_egg",
    name="Frostbite Egg",
    biome="tundra",
    rarity="secret",
    base="dark_blue",
    accent="ice",
    accent2="white",
    accent3="black",
    patterns=[("cracks", {"count": 4, "length": 8, "color": "neon_cyan", "seed": 9})],
    extras=[
        ("big_eye", {"iris": "neon_cyan", "at": 0.5}),
        ("spikes", {"color": "ice", "count": 8, "at": 0.32}),
    ],
    flavor="It bites back.",
)


def build():
    return build_egg(DESIGN)

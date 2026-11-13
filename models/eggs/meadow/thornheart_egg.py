"""Thornheart Egg: Clover Meadow · Secret egg. Nobody planted it. It grew anyway."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="thornheart_egg",
    name="Thornheart Egg",
    biome="meadow",
    rarity="secret",
    base="charcoal",
    accent="dark_green",
    accent2="white",
    accent3="black",
    patterns=[("vines", {"color": "dark_green", "turns": 3, "twist": 6.0, "leaf": "forest"})],
    extras=[
        ("spikes", {"color": "dark_green", "count": 10, "at": 0.45}),
        ("eyes_peek", {"color": "neon_red", "at": 0.66}),
    ],
    flavor="Nobody planted it. It grew anyway.",
)


def build():
    return build_egg(DESIGN)

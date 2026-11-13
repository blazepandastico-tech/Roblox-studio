"""Moon Blossom Egg: Blossom Hills · Mythic egg. Petals that only open under the moon."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="moon_blossom_egg",
    name="Moon Blossom Egg",
    biome="blossom",
    rarity="mythic",
    base="navy",
    accent="pink",
    accent2="white",
    accent3="black",
    patterns=[("spots", {"count": 6, "size": 0.7, "color": "pink", "seed": 6})],
    extras=[("moon", {"color": "light_yellow"})],
    flavor="Petals that only open under the moon.",
)


def build():
    return build_egg(DESIGN)

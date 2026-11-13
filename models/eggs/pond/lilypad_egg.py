"""Lilypad Egg: Lily Pond · Rare egg. Resting on a lily pad, waiting for spring."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="lilypad_egg",
    name="Lilypad Egg",
    biome="pond",
    rarity="rare",
    base="mint",
    accent="green",
    accent2="white",
    accent3="black",
    patterns=[("spots", {"count": 4, "size": 1.1, "color": "light_green", "seed": 3})],
    extras=[("lily_pad", {"color": "green", "flower": "pink"})],
    flavor="Resting on a lily pad, waiting for spring.",
)


def build():
    return build_egg(DESIGN)

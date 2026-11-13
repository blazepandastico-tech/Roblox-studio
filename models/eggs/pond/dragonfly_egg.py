"""Dragonfly Egg: Lily Pond · Legendary egg. Hums like a tiny engine."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="dragonfly_egg",
    name="Dragonfly Egg",
    biome="pond",
    rarity="legendary",
    base="teal",
    accent="navy",
    accent2="white",
    accent3="black",
    patterns=[("stripes", {"count": 6, "color": "dark_teal", "y": (0.15, 0.9)})],
    extras=[("wings", {"color": ("#E0F6FF", "glass"), "tip": "sky", "size": 5})],
    flavor="Hums like a tiny engine.",
)


def build():
    return build_egg(DESIGN)

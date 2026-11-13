"""Bamboo Egg: Blossom Hills · Uncommon egg. Grows a little taller every day."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="bamboo_egg",
    name="Bamboo Egg",
    biome="blossom",
    rarity="uncommon",
    base="lime",
    accent="olive",
    accent2="white",
    accent3="black",
    patterns=[("bands", {"at": (0.3, 0.6, 0.85), "width": 1, "color": "olive"})],
    extras=[("bamboo", {})],
    flavor="Grows a little taller every day.",
)


def build():
    return build_egg(DESIGN)

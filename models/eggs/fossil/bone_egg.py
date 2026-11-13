"""Bone Egg: Fossil Valley · Legendary egg. A fossil hunter's favourite."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="bone_egg",
    name="Bone Egg",
    biome="fossil",
    rarity="legendary",
    base="cream",
    accent="light_brown",
    accent2="white",
    accent3="black",
    patterns=[("bands", {"at": (0.3, 0.65), "width": 1, "color": "light_brown"})],
    extras=[("bone", {"color": "white"})],
    flavor="A fossil hunter's favourite.",
)


def build():
    return build_egg(DESIGN)

"""Black Hole Egg: Starlight Rim · Secret egg. Even light cannot escape it."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="black_hole_egg",
    name="Black Hole Egg",
    biome="starlight",
    rarity="secret",
    base="black",
    accent="fire",
    accent2="white",
    accent3="black",
    patterns=[],
    extras=[("planet_ring", {"color": "fire", "color2": "neon_yellow"})],
    flavor="Even light cannot escape it.",
)


def build():
    return build_egg(DESIGN)

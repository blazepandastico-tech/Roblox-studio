"""Deepmaw Egg: Coral Reef · Secret egg. All teeth, no manners."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="deepmaw_egg",
    name="Deepmaw Egg",
    biome="reef",
    rarity="secret",
    base="dark_blue",
    accent="white",
    accent2="white",
    accent3="black",
    patterns=[("art", {"rows": ["W.W.W.W", ".W.W.W."], "at": (None, 0.38), "colors": {"W": "white"}})],
    extras=[("eyes_peek", {"color": "neon_yellow", "at": 0.62})],
    flavor="All teeth, no manners.",
)


def build():
    return build_egg(DESIGN)

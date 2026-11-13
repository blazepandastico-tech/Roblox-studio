"""Jellyglow Egg: Coral Reef · Mythic egg. Wobbly, glowy, a little bit stingy."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="jellyglow_egg",
    name="Jellyglow Egg",
    biome="reef",
    rarity="mythic",
    base=("#FF9BE8", "glass"),
    accent="neon_pink",
    accent2="white",
    accent3="black",
    patterns=[],
    extras=[("inner", {"color": "neon_pink", "shape": "blob"}), ("sparkles", {"color": "neon_pink"})],
    flavor="Wobbly, glowy, a little bit stingy.",
)


def build():
    return build_egg(DESIGN)

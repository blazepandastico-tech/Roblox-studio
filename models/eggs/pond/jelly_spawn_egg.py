"""Jelly Spawn Egg: Lily Pond · Epic egg. Something small wiggles inside the jelly."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="jelly_spawn_egg",
    name="Jelly Spawn Egg",
    biome="pond",
    rarity="epic",
    base=("#9BE8C8", "glass"),
    accent="charcoal",
    accent2="white",
    accent3="black",
    patterns=[],
    extras=[("inner", {"color": "charcoal", "shape": "blob"})],
    flavor="Something small wiggles inside the jelly.",
)


def build():
    return build_egg(DESIGN)

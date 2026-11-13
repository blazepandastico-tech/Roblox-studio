"""Molten Core Egg: Ember Caldera · Secret egg. The volcano's heart. It is awake."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="molten_core_egg",
    name="Molten Core Egg",
    biome="caldera",
    rarity="secret",
    base="charcoal",
    accent="lava",
    accent2="white",
    accent3="black",
    patterns=[("cracks", {"count": 7, "length": 10, "color": "lava", "seed": 8})],
    extras=[("big_eye", {"iris": "fire", "at": 0.5})],
    flavor="The volcano's heart. It is awake.",
)


def build():
    return build_egg(DESIGN)

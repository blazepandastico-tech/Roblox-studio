"""Inferno Egg: Ember Caldera · Mythic egg. Handle with oven gloves."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="inferno_egg",
    name="Inferno Egg",
    biome="caldera",
    rarity="mythic",
    base="red",
    accent="fire",
    accent2="white",
    accent3="black",
    patterns=[("drips", {"from": 0.7, "color": "fire", "count": 8, "max_len": 3})],
    extras=[("flame", {"outer": "lava", "inner": "fire", "core": "neon_yellow"})],
    flavor="Handle with oven gloves.",
)


def build():
    return build_egg(DESIGN)

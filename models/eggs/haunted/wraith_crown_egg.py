"""Wraith Crown Egg: Haunted Hollow · Divine egg. Queen of the Haunted Hollow."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="wraith_crown_egg",
    name="Wraith Crown Egg",
    biome="haunted",
    rarity="divine",
    base="lavender",
    accent="violet",
    accent2="white",
    accent3="black",
    patterns=[("gradient", {"stops": ((0.6, "purple"),)})],
    extras=[("crown", {"color": "silver", "gem": "neon_purple"}), ("bat_wings", {"color": "dark_purple"})],
    flavor="Queen of the Haunted Hollow.",
)


def build():
    return build_egg(DESIGN)

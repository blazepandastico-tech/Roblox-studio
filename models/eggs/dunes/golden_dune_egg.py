"""Golden Dune Egg: Sunbaked Dunes · Divine egg. Shines brighter than the desert noon."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="golden_dune_egg",
    name="Golden Dune Egg",
    biome="dunes",
    rarity="divine",
    base="light_yellow",
    accent="gold",
    accent2="white",
    accent3="black",
    patterns=[("gradient", {"stops": ((0.45, "gold"), (0.8, "light_yellow"))})],
    extras=[("sun_disk", {"color": "glow"}), ("wings", {"color": "white", "tip": "gold"})],
    flavor="Shines brighter than the desert noon.",
)


def build():
    return build_egg(DESIGN)

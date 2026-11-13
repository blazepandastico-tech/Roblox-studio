"""Steam Egg: Clockwork Works · Epic egg. Puffs a little steam when happy."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="steam_egg",
    name="Steam Egg",
    biome="clockwork",
    rarity="epic",
    base="gunmetal",
    accent="copper",
    accent2="white",
    accent3="black",
    patterns=[("bands", {"at": (0.25, 0.55), "width": 2, "color": "copper"})],
    extras=[("pipe", {"color": "copper", "steam": "white"})],
    flavor="Puffs a little steam when happy.",
)


def build():
    return build_egg(DESIGN)

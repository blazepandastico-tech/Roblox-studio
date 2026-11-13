"""Tesla Egg: Clockwork Works · Mythic egg. Crackles with stored lightning."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="tesla_egg",
    name="Tesla Egg",
    biome="clockwork",
    rarity="mythic",
    base="dark_blue",
    accent="copper",
    accent2="white",
    accent3="black",
    patterns=[("bands", {"at": (0.2, 0.35, 0.5, 0.65), "width": 1, "color": "copper"})],
    extras=[
        ("lightning", {"color": "neon_cyan", "at": 0.85}),
        ("antenna", {"color": "steel", "tip": "neon_cyan"}),
    ],
    flavor="Crackles with stored lightning.",
    glow=("#3FF2FF", "glow"),
)


def build():
    return build_egg(DESIGN)

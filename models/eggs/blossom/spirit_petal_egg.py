"""Spirit Petal Egg: Blossom Hills · Celestial egg. Petals dance around it on their own."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="spirit_petal_egg",
    name="Spirit Petal Egg",
    biome="blossom",
    rarity="celestial",
    base="white",
    accent="pink",
    accent2="white",
    accent3="black",
    patterns=[("gradient", {"stops": ((0.55, "blush"), (0.8, "pink"))})],
    extras=[("petals", {"color": "pink", "color2": "white"}), ("sparkles", {"color": "neon_pink"})],
    flavor="Petals dance around it on their own.",
)


def build():
    return build_egg(DESIGN)

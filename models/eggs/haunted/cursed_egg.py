"""Cursed Egg: Haunted Hollow · Mythic egg. Whoever hatches it... good luck."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="cursed_egg",
    name="Cursed Egg",
    biome="haunted",
    rarity="mythic",
    base="dark_purple",
    accent="neon_green",
    accent2="white",
    accent3="black",
    patterns=[],
    extras=[("runes", {"color": "neon_green"}), ("chains", {"color": "gunmetal", "at": 0.4})],
    flavor="Whoever hatches it... good luck.",
    glow=("#6BFF5E", "glow"),
)


def build():
    return build_egg(DESIGN)

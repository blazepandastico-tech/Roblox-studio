"""Comet Egg: Starlight Rim · Rare egg. Zooms past once every hundred years."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="comet_egg",
    name="Comet Egg",
    biome="starlight",
    rarity="rare",
    base="sky",
    accent="white",
    accent2="white",
    accent3="black",
    patterns=[("speckle", {"colors": {"white": 1}, "fraction": 0.08, "seed": 5})],
    extras=[("comet_tail", {"colors": ("light", "neon_cyan", "sky")})],
    flavor="Zooms past once every hundred years.",
)


def build():
    return build_egg(DESIGN)

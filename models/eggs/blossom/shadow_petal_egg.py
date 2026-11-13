"""Shadow Petal Egg: Blossom Hills · Secret egg. Beautiful, quiet and a little bit sinister."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="shadow_petal_egg",
    name="Shadow Petal Egg",
    biome="blossom",
    rarity="secret",
    base="black",
    accent="neon_pink",
    accent2="white",
    accent3="black",
    patterns=[],
    extras=[
        ("petals", {"color": "neon_pink", "color2": "magenta"}),
        ("eyes_peek", {"color": "neon_pink", "at": 0.64}),
    ],
    flavor="Beautiful, quiet and a little bit sinister.",
)


def build():
    return build_egg(DESIGN)

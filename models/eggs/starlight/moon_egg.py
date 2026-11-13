"""Moon Egg: Starlight Rim · Uncommon egg. Bring your own craters."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="moon_egg",
    name="Moon Egg",
    biome="starlight",
    rarity="uncommon",
    base="light_gray",
    accent="gray",
    accent2="white",
    accent3="black",
    patterns=[
        ("spots", {"count": 7, "size": 1.4, "color": "dark_stone", "seed": 7}),
        ("speckle", {"colors": {"gray": 1}, "fraction": 0.2, "seed": 3}),
    ],
    extras=[],
    flavor="Bring your own craters.",
)


def build():
    return build_egg(DESIGN)

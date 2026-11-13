"""Rocket Egg: Starlight Rim · Legendary egg. 3... 2... 1... hatch!"""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="rocket_egg",
    name="Rocket Egg",
    biome="starlight",
    rarity="legendary",
    base="white",
    accent="red",
    accent2="white",
    accent3="black",
    patterns=[
        ("bottom", {"to": 0.18, "color": "red"}),
        (
            "art",
            {
                "rows": [".BB.", "BLLB", "BLLB", ".BB."],
                "at": (None, 0.66),
                "colors": {"B": "steel", "L": "light_blue"},
            },
        ),
    ],
    extras=[("fins", {"color": "red", "count": 4})],
    flavor="3... 2... 1... hatch!",
)


def build():
    return build_egg(DESIGN)

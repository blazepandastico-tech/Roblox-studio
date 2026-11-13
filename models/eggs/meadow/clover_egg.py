"""Clover Egg: Clover Meadow · Uncommon egg. Four leaves for four times the luck."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="clover_egg",
    name="Clover Egg",
    biome="meadow",
    rarity="uncommon",
    base="green",
    accent="light_green",
    accent2="white",
    accent3="black",
    patterns=[
        ("dots", {"rows": (0.25, 0.5, 0.75), "count": 6, "color": "lime"}),
        (
            "art",
            {
                "rows": [".GG.GG.", "GGGGGGG", ".GGGGG.", "GGGGGGG", ".GG.GG."],
                "at": (None, 0.62),
                "colors": {"G": "lime"},
                "emboss": True,
            },
        ),
    ],
    extras=[],
    flavor="Four leaves for four times the luck.",
)


def build():
    return build_egg(DESIGN)

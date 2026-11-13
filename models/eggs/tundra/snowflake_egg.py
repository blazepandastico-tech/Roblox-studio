"""Snowflake Egg: Frostpeak Tundra · Epic egg. No two are ever the same."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="snowflake_egg",
    name="Snowflake Egg",
    biome="tundra",
    rarity="epic",
    base="blue",
    accent="white",
    accent2="white",
    accent3="black",
    patterns=[
        ("dots", {"rows": (0.22, 0.8), "count": 8, "color": "white"}),
        (
            "art",
            {
                "rows": ["W.W.W", ".WWW.", "WWWWW", ".WWW.", "W.W.W"],
                "at": (None, 0.6),
                "colors": {"W": "white"},
            },
        ),
    ],
    extras=[],
    flavor="No two are ever the same.",
)


def build():
    return build_egg(DESIGN)

"""Pocketwatch Egg: Clockwork Works · Legendary egg. Always exactly on time."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="pocketwatch_egg",
    name="Pocketwatch Egg",
    biome="clockwork",
    rarity="legendary",
    base=("#E8B32A", "metal"),
    accent="white",
    accent2="white",
    accent3="black",
    patterns=[
        (
            "art",
            {
                "rows": [".WWW.", "WWKWW", "WWKKW", "WWWWW", ".WWW."],
                "at": (None, 0.6),
                "colors": {"W": "white", "K": "black"},
            },
        )
    ],
    extras=[("antenna", {"color": "gold", "tip": "gold"})],
    flavor="Always exactly on time.",
)


def build():
    return build_egg(DESIGN)

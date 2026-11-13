"""Paper Lantern Egg: Blossom Hills · Rare egg. Glows warm on festival nights."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="paper_lantern_egg",
    name="Paper Lantern Egg",
    biome="blossom",
    rarity="rare",
    base="red",
    accent="gold",
    accent2="white",
    accent3="black",
    patterns=[
        ("bands", {"at": (0.15, 0.85), "width": 1, "color": "gold"}),
        ("cap", {"from": 0.93, "color": "gold"}),
        ("bottom", {"to": 0.06, "color": "gold"}),
    ],
    extras=[("lantern_ring", {"color": "gold"})],
    flavor="Glows warm on festival nights.",
)


def build():
    return build_egg(DESIGN)

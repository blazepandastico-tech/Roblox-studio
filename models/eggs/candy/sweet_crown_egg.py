"""Sweet Crown Egg: Sugar Isles · Divine egg. Ruler of the Sugar Isles."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="sweet_crown_egg",
    name="Sweet Crown Egg",
    biome="candy",
    rarity="divine",
    base="light_yellow",
    accent="pink",
    accent2="white",
    accent3="black",
    patterns=[("drips", {"from": 0.6, "color": "pink", "count": 9, "max_len": 3})],
    extras=[("crown", {"color": "gold", "gem": "hot_pink"}), ("wings", {"color": "white", "tip": "pink"})],
    flavor="Ruler of the Sugar Isles.",
)


def build():
    return build_egg(DESIGN)

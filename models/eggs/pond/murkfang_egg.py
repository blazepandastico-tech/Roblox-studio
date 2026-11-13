"""Murkfang Egg: Lily Pond · Secret egg. Two eyes watch from under the algae."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="murkfang_egg",
    name="Murkfang Egg",
    biome="pond",
    rarity="secret",
    base="olive",
    accent="forest",
    accent2="white",
    accent3="black",
    patterns=[("drips", {"from": 0.66, "color": "forest", "count": 8, "max_len": 3})],
    extras=[("big_eye", {"iris": "neon_green", "at": 0.5})],
    flavor="Two eyes watch from under the algae.",
)


def build():
    return build_egg(DESIGN)

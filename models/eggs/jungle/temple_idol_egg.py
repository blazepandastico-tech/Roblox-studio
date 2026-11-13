"""Temple Idol Egg: Vine Jungle · Secret egg. The idol's eyes are watching you."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="temple_idol_egg",
    name="Temple Idol Egg",
    biome="jungle",
    rarity="secret",
    base="stone",
    accent="moss",
    accent2="white",
    accent3="black",
    patterns=[("speckle", {"colors": {"moss": 1}, "fraction": 0.25, "seed": 3})],
    extras=[("runes", {"color": "neon_red"}), ("chains", {"color": "bronze", "at": 0.3})],
    flavor="The idol's eyes are watching you.",
)


def build():
    return build_egg(DESIGN)

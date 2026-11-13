"""Shadow Eye Egg: Haunted Hollow · Secret egg. It sees you. It always sees you."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="shadow_eye_egg",
    name="Shadow Eye Egg",
    biome="haunted",
    rarity="secret",
    base="black",
    accent="neon_purple",
    accent2="white",
    accent3="black",
    patterns=[],
    extras=[("big_eye", {"iris": "neon_purple", "at": 0.5})],
    flavor="It sees you. It always sees you.",
)


def build():
    return build_egg(DESIGN)

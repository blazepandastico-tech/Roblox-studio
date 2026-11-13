"""Storm Eye Egg: Sky Citadel · Secret egg. Calm in the middle of the storm."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="storm_eye_egg",
    name="Storm Eye Egg",
    biome="sky",
    rarity="secret",
    base="slate",
    accent="gray",
    accent2="white",
    accent3="black",
    patterns=[("swirl", {"count": 2, "twist": 7.0, "color": "gray"})],
    extras=[("big_eye", {"iris": "neon_cyan", "at": 0.5})],
    flavor="Calm in the middle of the storm.",
)


def build():
    return build_egg(DESIGN)

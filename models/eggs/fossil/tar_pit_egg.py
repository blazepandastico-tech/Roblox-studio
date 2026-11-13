"""Tar Pit Egg: Fossil Valley · Secret egg. Something climbed out of the tar."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="tar_pit_egg",
    name="Tar Pit Egg",
    biome="fossil",
    rarity="secret",
    base="black",
    accent="dark_brown",
    accent2="white",
    accent3="black",
    patterns=[("drips", {"from": 0.5, "color": "dark_brown", "count": 8, "max_len": 4})],
    extras=[("eyes_peek", {"color": "neon_yellow", "at": 0.68})],
    flavor="Something climbed out of the tar.",
)


def build():
    return build_egg(DESIGN)

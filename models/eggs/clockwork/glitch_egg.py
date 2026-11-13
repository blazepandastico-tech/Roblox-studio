"""Glitch Egg: Clockwork Works · Secret egg. ERR0R: egg.exe has stopped responding."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="glitch_egg",
    name="Glitch Egg",
    biome="clockwork",
    rarity="secret",
    base="black",
    accent="neon_green",
    accent2="white",
    accent3="black",
    patterns=[("checker", {"count": 10, "rows": 1, "color": "neon_green", "y": (0.35, 0.65)})],
    extras=[("eyes_peek", {"color": "neon_red", "at": 0.75})],
    flavor="ERR0R: egg.exe has stopped responding.",
)


def build():
    return build_egg(DESIGN)

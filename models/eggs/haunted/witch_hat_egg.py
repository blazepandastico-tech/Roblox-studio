"""Witch Hat Egg: Haunted Hollow · Celestial egg. Comes with its own hat and a spell or two."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="witch_hat_egg",
    name="Witch Hat Egg",
    biome="haunted",
    rarity="celestial",
    base="purple",
    accent="lime",
    accent2="white",
    accent3="black",
    patterns=[("bands", {"at": (0.3,), "width": 1, "color": "dark_purple"})],
    extras=[("witch_hat", {"color": "dark_purple", "band": "lime"}), ("sparkles", {"color": "neon_green"})],
    flavor="Comes with its own hat and a spell or two.",
)


def build():
    return build_egg(DESIGN)

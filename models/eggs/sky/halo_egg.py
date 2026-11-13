"""Halo Egg: Sky Citadel · Celestial egg. Blessed and very well behaved."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="halo_egg",
    name="Halo Egg",
    biome="sky",
    rarity="celestial",
    base="white",
    accent="light_yellow",
    accent2="white",
    accent3="black",
    patterns=[("cap", {"from": 0.82, "color": "light_yellow"})],
    extras=[("halo", {"color": "glow"}), ("sparkles", {"color": "neon_yellow"})],
    flavor="Blessed and very well behaved.",
)


def build():
    return build_egg(DESIGN)

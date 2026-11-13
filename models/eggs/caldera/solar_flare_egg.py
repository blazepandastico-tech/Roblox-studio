"""Solar Flare Egg: Ember Caldera · Divine egg. A piece of the sun fell here."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="solar_flare_egg",
    name="Solar Flare Egg",
    biome="caldera",
    rarity="divine",
    base="orange",
    accent="yellow",
    accent2="white",
    accent3="black",
    patterns=[("gradient", {"stops": ((0.5, "yellow"), (0.85, "light_yellow"))})],
    extras=[("rays", {"color": "fire"}), ("wings", {"color": "light_yellow", "tip": "fire"})],
    flavor="A piece of the sun fell here.",
)


def build():
    return build_egg(DESIGN)

"""Automaton Egg: Clockwork Works · Celestial egg. Beep. Boop. Hatch."""

from studvox.eggs import EggDesign, build_egg

DESIGN = EggDesign(
    id="automaton_egg",
    name="Automaton Egg",
    biome="clockwork",
    rarity="celestial",
    base="steel",
    accent="gunmetal",
    accent2="white",
    accent3="black",
    patterns=[
        ("panels", {"color": "gunmetal", "count": 6, "rows": (0.3, 0.7)}),
        (
            "art",
            {"rows": ["KKK", "KCK", "KKK"], "at": (None, 0.6), "colors": {"K": "gunmetal", "C": "neon_cyan"}},
        ),
    ],
    extras=[("orbit", {"color": "neon_cyan", "count": 3})],
    flavor="Beep. Boop. Hatch.",
)


def build():
    return build_egg(DESIGN)

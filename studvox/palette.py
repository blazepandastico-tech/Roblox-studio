"""Named stud-style colours.

Every model gets its own palette made from the colours it actually uses.
Colours can be referenced by name (``"red"``), by hex (``"#ff8800"``) or by
names registered on the model with :meth:`studvox.Model.add_color`.

Materials
---------
``plastic``  default glossy brick plastic (Roblox: SmoothPlastic)
``matte``    rough plastic, good for rock, wood, fur (Roblox: SmoothPlastic)
``metal``    shiny metal (Roblox: Metal-ish SmoothPlastic with reflectance)
``glow``     emissive, no studs by default (Roblox: Neon)
``glass``    see-through (Roblox: Glass, Transparency 0.35)
``water``    see-through blue-ish, no studs by default (Roblox: Glass, Transparency 0.25)
"""

from __future__ import annotations

MATERIALS = ("plastic", "matte", "metal", "glow", "glass", "water")

# name -> (hex, material)
DEFAULT_PALETTE: dict[str, tuple[str, str]] = {
    # neutrals
    "white": ("#F4F4F2", "plastic"),
    "cream": ("#FFF1D6", "plastic"),
    "light_gray": ("#C5C9CF", "plastic"),
    "gray": ("#9298A0", "plastic"),
    "dark_gray": ("#5C626B", "plastic"),
    "charcoal": ("#3A3E45", "plastic"),
    "black": ("#1D1E22", "plastic"),
    # reds / pinks
    "red": ("#E2312E", "plastic"),
    "dark_red": ("#9A1C1F", "plastic"),
    "maroon": ("#5E1418", "plastic"),
    "coral": ("#FF7A6B", "plastic"),
    "pink": ("#FF9BC8", "plastic"),
    "hot_pink": ("#F2489B", "plastic"),
    "magenta": ("#C21E78", "plastic"),
    "blush": ("#FFC1CF", "plastic"),
    # oranges / yellows
    "orange": ("#FF8A1C", "plastic"),
    "dark_orange": ("#D9601A", "plastic"),
    "peach": ("#FFB98A", "plastic"),
    "yellow": ("#FFD321", "plastic"),
    "light_yellow": ("#FFED8A", "plastic"),
    "gold": ("#E8A82A", "metal"),
    "mustard": ("#D9A21B", "plastic"),
    # greens
    "lime": ("#A6DE3A", "plastic"),
    "light_green": ("#7BD45A", "plastic"),
    "green": ("#3DAE4A", "plastic"),
    "dark_green": ("#22803A", "plastic"),
    "forest": ("#1A5A30", "plastic"),
    "olive": ("#7E8B2E", "plastic"),
    "mint": ("#97E8C8", "plastic"),
    "teal": ("#1AA39B", "plastic"),
    "dark_teal": ("#0E6B6A", "plastic"),
    # blues / purples
    "sky": ("#74C8FF", "plastic"),
    "light_blue": ("#A9DDFF", "plastic"),
    "blue": ("#2F7BE8", "plastic"),
    "dark_blue": ("#1F4699", "plastic"),
    "navy": ("#16264F", "plastic"),
    "lavender": ("#BDA6F7", "plastic"),
    "purple": ("#7C4DD6", "plastic"),
    "dark_purple": ("#472783", "plastic"),
    "violet": ("#A23FD6", "plastic"),
    # browns / skin
    "sand": ("#E4C994", "matte"),
    "tan": ("#D2A86E", "matte"),
    "light_brown": ("#B57B45", "matte"),
    "brown": ("#8A5530", "matte"),
    "dark_brown": ("#5B3720", "matte"),
    "reddish_brown": ("#7B3B24", "matte"),
    "skin": ("#F6C79B", "plastic"),
    "skin_dark": ("#A86E48", "plastic"),
    # stone / earth
    "stone": ("#A7A39C", "matte"),
    "dark_stone": ("#76736E", "matte"),
    "slate": ("#5B6470", "matte"),
    "moss": ("#5F8F3A", "matte"),
    "grass": ("#59B84A", "matte"),
    "dark_grass": ("#3B8E3A", "matte"),
    "dirt": ("#8C5E3C", "matte"),
    "dark_dirt": ("#66412A", "matte"),
    "snow": ("#F3F8FF", "matte"),
    # metals
    "silver": ("#C9D0D8", "metal"),
    "steel": ("#8A949F", "metal"),
    "gunmetal": ("#454C55", "metal"),
    "bronze": ("#B8743A", "metal"),
    "copper": ("#C7673A", "metal"),
    # glow
    "neon_cyan": ("#3FF2FF", "glow"),
    "neon_green": ("#6BFF5E", "glow"),
    "neon_pink": ("#FF4FD8", "glow"),
    "neon_purple": ("#B45CFF", "glow"),
    "neon_yellow": ("#FFF24A", "glow"),
    "neon_red": ("#FF3B30", "glow"),
    "fire": ("#FF8A1A", "glow"),
    "lava": ("#FF4D12", "glow"),
    "light": ("#FFF6C8", "glow"),
    # see-through
    "glass": ("#BFE8FF", "glass"),
    "ice": ("#CDEFFF", "glass"),
    "crystal": ("#C3A8FF", "glass"),
    "water": ("#3D9DF0", "water"),
    "deep_water": ("#2268C9", "water"),
    "foam": ("#E8F7FF", "matte"),
}


def parse_hex(value: str) -> tuple[int, int, int]:
    s = value.strip().lstrip("#")
    if len(s) == 3:
        s = "".join(c * 2 for c in s)
    if len(s) != 6:
        raise ValueError(f"bad hex colour {value!r}")
    return int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16)


def to_hex(rgb: tuple[int, int, int]) -> str:
    return "#{:02X}{:02X}{:02X}".format(*rgb)


def srgb_to_linear(c: float) -> float:
    c = c / 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def shade(hex_value: str, amount: float) -> str:
    """Lighten (amount>0) or darken (amount<0) a hex colour, amount in -1..1."""
    r, g, b = parse_hex(hex_value)
    if amount >= 0:
        r, g, b = (int(round(v + (255 - v) * amount)) for v in (r, g, b))
    else:
        r, g, b = (int(round(v * (1 + amount))) for v in (r, g, b))
    return to_hex((r, g, b))


def default_studs_for(material: str) -> bool:
    return material not in ("glow", "water")

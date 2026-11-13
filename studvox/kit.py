"""Reusable building blocks for model specs: faces, limbs and stock animation clips.

Everything here is plain helper code on top of :class:`studvox.Model` /
:class:`studvox.Part`; use it or copy and tweak it in your own spec.
"""

from __future__ import annotations

from typing import Sequence

from .model import Model, Part

# ---------------------------------------------------------------------------- faces

FACES = {
    # 2x2 eyes with a white shine, rows top -> bottom, symmetric around x = 0
    "cute": [".WB.....WB.", ".BB.....BB."],
    "cute_small": [".W...W.", ".B...B."],
    "dots": ["B...B"],
    "angry": ["BB.....BB", ".BB...BB.", "..B...B.."],
    "sleepy": ["BBB...BBB"],
    "big": ["WWB.....WWB", "WBB.....WBB", "BBB.....BBB"],
}


def face(part: Part, style: str | Sequence[str], *, y: int, z: int | None = None, x: int | None = None,
         colors: dict | None = None, facing: str = "+z") -> Part:
    """Paint eyes (or any ASCII art) centred on x = 0 at row ``y`` on the front of ``part``."""
    rows = (FACES.get(style, [style])) if isinstance(style, str) else list(style)
    width = max(len(r) for r in rows)
    x0 = -(width // 2) if x is None else x
    cols = {"W": "white", "B": "black", "P": "pink", "R": "red", "O": "orange", "Y": "yellow", "G": "green",
            "N": "dark_brown", "K": "charcoal", "C": "neon_cyan", "L": "lava", "V": "neon_purple"}
    cols.update(colors or {})
    return part.decal(rows, at=(x0, y, 0 if z is None else z), colors=cols, facing=facing)


# ---------------------------------------------------------------------------- clips

def idle_breathe(m: Model, *, body="body", head: str | None = "head", length=2.0, bob=0.25, tilt=4.0,
                 extra: Sequence[tuple[str, tuple, float]] = ()):
    """Gentle bob + head tilt. ``extra`` = [(part, rot_amplitude, phase), ...] for ears, tails, wings."""
    c = m.clip("idle", length)
    c.osc(body, pos=(0, bob, 0), period=length / 2)
    if head:
        c.osc(head, rot=(tilt * 0.6, 0, tilt), period=length, phase=0.15)
    for part, rot, phase in extra:
        c.osc(part, rot=rot, period=length / 2, phase=phase)
    return c


def walk_biped(m: Model, *, body="body", legs=("leg_l", "leg_r"), arms=("arm_l", "arm_r"), head: str | None = None,
               length=0.8, swing=30.0, arm_swing=None, bob=0.4, sway=4.0, name="walk"):
    c = m.clip(name, length)
    c.osc(body, pos=(0, bob, 0), period=length / 2, wave="bounce")
    c.osc(body, rot=(0, sway, sway * 0.6), period=length)
    if legs:
        c.osc(legs[0], rot=(swing, 0, 0), period=length)
        c.osc(legs[1], rot=(-swing, 0, 0), period=length)
    if arms:
        a = swing if arm_swing is None else arm_swing
        c.osc(arms[0], rot=(-a, 0, 0), period=length)
        c.osc(arms[1], rot=(a, 0, 0), period=length)
    if head:
        c.osc(head, rot=(3, -sway, 0), period=length)
    return c


def walk_quad(m: Model, *, body="body", legs=("leg_fl", "leg_fr", "leg_bl", "leg_br"), head: str | None = "head",
              tail: str | None = None, length=0.7, swing=28.0, bob=0.3, name="walk"):
    """Trot: diagonal legs move together."""
    c = m.clip(name, length)
    c.osc(body, pos=(0, bob, 0), period=length / 2, wave="bounce")
    fl, fr, bl, br = legs
    c.osc(fl, rot=(swing, 0, 0), period=length)
    c.osc(br, rot=(swing, 0, 0), period=length)
    c.osc(fr, rot=(-swing, 0, 0), period=length)
    c.osc(bl, rot=(-swing, 0, 0), period=length)
    if head:
        c.osc(head, rot=(4, 0, 0), period=length / 2)
    if tail:
        c.osc(tail, rot=(0, 18, 0), period=length)
    return c


def hop(m: Model, *, body="body", length=0.7, height=2.5, squash=8.0, name="hop", loop=True, parts=()):
    c = m.clip(name, length, loop=loop)
    c.osc(body, pos=(0, height, 0), period=length, wave="bounce")
    c.osc(body, rot=(squash, 0, 0), period=length)
    for p, rot in parts:
        c.osc(p, rot=rot, period=length)
    return c


def flap(clip, left: str, right: str, *, amp=35.0, period=0.3, axis="z"):
    i = "xyz".index(axis)
    r = [0.0, 0.0, 0.0]
    r[i] = amp
    clip.osc(left, rot=tuple(r), period=period)
    clip.osc(right, rot=tuple(-v for v in r), period=period)
    return clip


def wave_chain(clip, parts: Sequence[str], *, rot=(0, 15, 0), period=1.0, phase_step=0.12):
    """Travelling wave along a chain of parts (tails, tentacles, necks)."""
    for i, p in enumerate(parts):
        clip.osc(p, rot=rot, period=period, phase=-i * phase_step)
    return clip


def attack_lunge(m: Model, *, body="body", head: str | None = "head", parts: Sequence[tuple[str, tuple]] = (),
                 length=1.0, lunge=3.0, name="attack"):
    """Wind up, strike forward, recover. ``parts`` = [(part, strike_rot), ...]."""
    c = m.clip(name, length, loop=False)
    t1, t2 = length * 0.35, length * 0.5
    c.keys(body, [(0, {}), (t1, {"pos": (0, 0, -lunge * 0.4), "rot": (-8, 0, 0)}),
                  (t2, {"pos": (0, 0, lunge), "rot": (10, 0, 0), "ease": "back"}), (length, {})])
    if head:
        c.keys(head, [(0, {}), (t1, {"rot": (-15, 0, 0)}), (t2, {"rot": (15, 0, 0)}), (length, {})])
    for p, rot in parts:
        wind = tuple(-v * 0.5 for v in rot)
        c.keys(p, [(0, {}), (t1, {"rot": wind}), (t2, {"rot": rot, "ease": "back"}), (length, {})])
    return c

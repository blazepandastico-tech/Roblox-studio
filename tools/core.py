"""Primitive model builder shared by the preview renderer and the Roblox exporters.

Conventions: Y is up, the model front faces +Z, units are studs.
Primitive kinds: 'box', 'ball' (ellipsoid), 'cyl' (cylinder with its axis along Y).
"""
import math

import numpy as np


def H(s):
    s = s.lstrip('#')
    return tuple(int(s[i:i + 2], 16) for i in (0, 2, 4))


def mix(a, b, t):
    a, b = H(a), H(b)
    return '#%02x%02x%02x' % tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def dark(c, t=0.25):
    return mix(c, '#000000', t)


def light(c, t=0.3):
    return mix(c, '#ffffff', t)


def rot_matrix(rx=0, ry=0, rz=0):
    """Same as Roblox CFrame.Angles(rx, ry, rz) = Rx * Ry * Rz (degrees in)."""
    a, b, c = map(math.radians, (rx, ry, rz))
    Rx = np.array([[1, 0, 0], [0, math.cos(a), -math.sin(a)], [0, math.sin(a), math.cos(a)]])
    Ry = np.array([[math.cos(b), 0, math.sin(b)], [0, 1, 0], [-math.sin(b), 0, math.cos(b)]])
    Rz = np.array([[math.cos(c), -math.sin(c), 0], [math.sin(c), math.cos(c), 0], [0, 0, 1]])
    return Rx @ Ry @ Rz


class Part:
    __slots__ = ('kind', 'pos', 'size', 'rot', 'color', 'mat', 'tr')

    def __init__(self, kind, pos, size, rot, color, mat, tr):
        self.kind, self.pos, self.size, self.rot = kind, tuple(pos), tuple(size), tuple(rot)
        self.color, self.mat, self.tr = color, mat, tr


class Model:
    def __init__(self, name, tier='Common'):
        self.name, self.tier, self.parts = name, tier, []

    def _add(self, kind, pos, size, color, mat, rot, tr):
        if isinstance(size, (int, float)):
            size = (size, size, size)
        self.parts.append(Part(kind, pos, size, rot, color, mat, tr))

    def box(self, pos, size, color, mat='SmoothPlastic', rot=(0, 0, 0), tr=0):
        self._add('box', pos, size, color, mat, rot, tr)

    def ball(self, pos, size, color, mat='SmoothPlastic', rot=(0, 0, 0), tr=0):
        self._add('ball', pos, size, color, mat, rot, tr)

    def cyl(self, pos, size, color, mat='SmoothPlastic', rot=(0, 0, 0), tr=0):
        """size = (diameter_x, height, diameter_z) with the axis along local Y."""
        self._add('cyl', pos, size, color, mat, rot, tr)

    def bounds(self):
        lo, hi = np.full(3, 1e9), np.full(3, -1e9)
        for p in self.parts:
            R = rot_matrix(*p.rot)
            for dx in (-.5, .5):
                for dy in (-.5, .5):
                    for dz in (-.5, .5):
                        v = R @ (np.array([dx, dy, dz]) * p.size) + p.pos
                        lo, hi = np.minimum(lo, v), np.maximum(hi, v)
        return lo, hi


TIER_COLORS = {
    'Common': '#bfc5cc', 'Uncommon': '#5ee06a', 'Rare': '#4aa8ff',
    'Epic': '#b468ff', 'Legendary': '#ffc933', 'Mythic': '#ff4a4a',
}

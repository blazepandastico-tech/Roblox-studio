"""StudVox: stud-style voxel models for Roblox.

Write a model spec (a Python file with ``build() -> Model``), then run::

    python -m studvox make models/critters/duck.py

which bakes the model, builds it in Blender (studs, black outline, rig,
animation), renders previews and a concept sheet, and exports FBX / GLB / OBJ
plus a Studio-ready ``.rbxmx`` and a Luau data module.
"""

from . import shapes
from . import shapes as S
from .anim import Clip
from .model import CATEGORIES, CATEGORY_VOXEL_SIZE, NOSTUD, Model, Part
from .palette import DEFAULT_PALETTE, shade

__all__ = ["Model", "Part", "Clip", "S", "shapes", "DEFAULT_PALETTE", "CATEGORIES", "CATEGORY_VOXEL_SIZE",
           "NOSTUD", "shade"]
__version__ = "1.0.0"

"""Traced model: Cactus Pal. Regenerate with `python -m studvox make models/traced/cactus_pal.py`."""

from studvox.trace import trace_model


def build():
    return trace_model(
        "references/cactus_pal.png",
        name="cactus_pal",
        title="Cactus Pal",
        category="traced",
        height=40,
        depth=0.0,
        colors=12,
        outline="auto",
        side=None,
        voxel_size=0.2,
    )

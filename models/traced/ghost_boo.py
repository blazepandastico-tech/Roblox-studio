"""Traced model: Ghost Boo. Regenerate with `python -m studvox make models/traced/ghost_boo.py`."""

from studvox.trace import trace_model


def build():
    return trace_model(
        "references/ghost_boo.png",
        name="ghost_boo",
        title="Ghost Boo",
        category="traced",
        height=40,
        depth=0.0,
        colors=12,
        outline="auto",
        side=None,
        voxel_size=0.2,
    )

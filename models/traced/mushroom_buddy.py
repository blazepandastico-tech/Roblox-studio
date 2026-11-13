"""Traced model: Mushroom Buddy. Regenerate with `python -m studvox make models/traced/mushroom_buddy.py`."""

from studvox.trace import trace_model


def build():
    return trace_model(
        "references/mushroom_buddy.png",
        name="mushroom_buddy",
        title="Mushroom Buddy",
        category="traced",
        height=40,
        depth=0.0,
        colors=12,
        outline="auto",
        side=None,
        voxel_size=0.2,
    )

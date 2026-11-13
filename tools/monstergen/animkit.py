"""Shared gait helpers for the pose functions."""
from rig import mir, wave


def step(t, T, phase, swing, lift, front=True, flat=0.85):
    """One leg of a walk cycle -> (upper, lower, foot) rotations about X.
    The foot is in the air while the leg swings forward."""
    s = wave(t, T, phase)
    air = max(0.0, wave(t, T, phase + 0.25))
    up = swing * s
    lo = (-lift if front else lift) * air
    return (up, 0, 0), (lo, 0, 0), (-(up + lo) * flat, 0, 0)


def set3(pose, names, vals):
    for n, v in zip(names, vals):
        pose[n] = v


def sym(pose, name, left):
    """Same motion on both sides: '{}' in name is replaced by L / R."""
    pose[name.format("L")] = left
    pose[name.format("R")] = mir(left)


def chain(pose, prefix, count, fn):
    """pose[prefix1..N] = fn(i) with i = 0..N-1."""
    for i in range(count):
        pose[f"{prefix}{i + 1}"] = fn(i)

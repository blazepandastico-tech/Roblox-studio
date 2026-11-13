"""Loading model specs and reading/writing baked ``.svox.json`` files."""

from __future__ import annotations

import importlib.util
import json
import sys
from pathlib import Path

from .model import Model


def load_spec(path: str | Path) -> Model:
    """Import a model spec file and call its ``build()``."""
    path = Path(path).resolve()
    mod_name = f"studvox_spec_{path.stem}_{abs(hash(str(path))) % 10_000_000}"
    spec = importlib.util.spec_from_file_location(mod_name, path)
    if spec is None or spec.loader is None:
        raise ImportError(f"cannot import {path}")
    mod = importlib.util.module_from_spec(spec)
    sys.modules[mod_name] = mod
    old_path = list(sys.path)
    sys.path.insert(0, str(path.parent))
    try:
        spec.loader.exec_module(mod)
    finally:
        sys.path[:] = old_path
    if not hasattr(mod, "build"):
        raise AttributeError(f"{path} must define build() -> studvox.Model")
    model = mod.build()
    if not isinstance(model, Model):
        raise TypeError(f"{path}: build() must return a studvox.Model, got {type(model).__name__}")
    model.meta.setdefault("spec", path.name)
    return model


def save(data: dict, path: str | Path) -> Path:
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, separators=(",", ":"))
    return path


def load(path: str | Path) -> dict:
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    if data.get("format") != "studvox":
        raise ValueError(f"{path} is not a studvox model")
    return data

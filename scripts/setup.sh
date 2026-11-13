#!/usr/bin/env bash
# StudVox setup: Python deps, and the Blender `bpy` module if no Blender app is installed.
#   bash scripts/setup.sh
set -euo pipefail
cd "$(dirname "$0")/.."

python3 -m pip install -r requirements.txt

if command -v blender >/dev/null 2>&1 || [ -n "${STUDVOX_BLENDER:-}" ]; then
  echo "Blender found: $(command -v blender || echo "$STUDVOX_BLENDER")"
else
  # bpy wheels are built for one Python version per Blender release (bpy 5.x -> Python 3.13, bpy 4.2-4.5 -> 3.11)
  PY=""
  for cand in python3.13 python3.11; do
    if command -v "$cand" >/dev/null 2>&1; then PY="$cand"; break; fi
  done
  if [ -z "$PY" ]; then
    echo "No Blender and no Python 3.13/3.11 for the bpy module."
    echo "Install Blender 4.2+ from https://www.blender.org/download/ and put it on PATH (or set STUDVOX_BLENDER)."
    exit 1
  fi
  echo "Installing the bpy module into .venv-bpy with $PY (about 400 MB)..."
  "$PY" -m venv .venv-bpy
  .venv-bpy/bin/python -m pip install --upgrade pip
  if [ "$PY" = "python3.13" ]; then
    .venv-bpy/bin/python -m pip install "bpy>=5.0" numpy pillow
  else
    .venv-bpy/bin/python -m pip install "bpy>=4.2,<5" numpy pillow
  fi
fi

python3 -m studvox doctor

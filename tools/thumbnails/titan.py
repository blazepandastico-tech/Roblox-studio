"""Carica il Gigante della Furia (modello Meshy) e lo mette in posa."""
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "mesh_titan"))
from convert import assign, read_fbx, skeleton, to_roblox  # noqa: E402

from engine import normalize, rot_x, rot_y, rot_z, vertex_normals  # noqa: E402

_cache = {}


def load(fbx_dir):
    if "m" in _cache:
        return _cache["m"]
    name = [f for f in os.listdir(fbx_dir) if f.endswith(".fbx")][0]
    V, T, UV, TUV = read_fbx(os.path.join(fbx_dir, name))
    P = to_roblox(V)
    J = skeleton(P)
    names, label = assign(P, T, J)
    # vertici separati per (posizione, uv, parte del corpo): ogni parte si muove senza stirare le altre
    pos_idx = T.reshape(-1)
    uv_idx = TUV.reshape(-1)
    lab = np.repeat(label, 3)
    key = (pos_idx.astype(np.int64) * 1_000_003 + uv_idx) * 32 + lab
    uniq, first, inv = np.unique(key, return_index=True, return_inverse=True)
    Vp = P[pos_idx[first]]
    Vuv = UV[uv_idx[first]]
    F = inv.reshape(-1, 3)
    Nfull = vertex_normals(P, T)
    N = Nfull[pos_idx[first]]
    part = np.array(names)[lab[first]]
    # via i triangoli "ponte" lunghi e sottili (es. tra la mano e la coscia) che si stirerebbero
    e = np.maximum.reduce([np.linalg.norm(Vp[F[:, a]] - Vp[F[:, b]], axis=1) for a, b in ((0, 1), (1, 2), (2, 0))])
    F = F[e < 0.022]
    tex_path = os.path.join(fbx_dir, name.replace(".fbx", ".png"))
    tex = np.asarray(Image.open(tex_path).convert("RGB")).astype(np.float64) / 255.0
    m = {"V": Vp, "F": F, "N": N, "UV": Vuv, "tex": tex, "J": J, "part": part}
    _cache["m"] = m
    return m


POSES = {
    # (spalla: apertura laterale, in avanti), (gomito: piega), testa (in su), busto (in avanti)
    "roar": {"arm": (0.42, 0.55), "elbow": 1.35, "head": 0.32, "spine": 0.12},
    "attack": {"armR": (0.25, 1.5), "elbowR": 0.3, "armL": (0.45, -0.4), "elbowL": 1.3, "head": -0.1, "spine": 0.18},
    "stand": {"arm": (0.12, 0.05), "elbow": 0.25, "head": 0.0, "spine": 0.0},
    "stare": {"arm": (0.42, 0.55), "elbow": 1.35, "head": -0.12, "spine": 0.22},
}


def _apply(V, N, mask, pivot, R):
    V = V.copy()
    N = N.copy()
    V[mask] = (V[mask] - pivot) @ R.T + pivot
    N[mask] = N[mask] @ R.T
    return V, N


def _rot_about(V, pivot, R):
    return (V - pivot) @ R.T + pivot


def posed(m, pose="roar", amount=1.0):
    """Posa con pesi morbidi vicino alle articolazioni (spalle, gomiti, collo, vita)."""
    V0 = m["V"]
    N0 = m["N"]
    if pose is None:
        return V0.copy(), N0.copy()
    cfg = {}
    for key, val in POSES[pose].items():
        cfg[key] = tuple(x * amount for x in val) if isinstance(val, tuple) else val * amount
    J = {k: np.array(v, dtype=np.float64) for k, v in m["J"].items()}
    part = m["part"]
    V = V0.copy()
    N = N0.copy()

    def blend(Va, Vb, Na, Nb, w):
        w = w[:, None]
        return Va * (1 - w) + Vb * w, normalize(Na * (1 - w) + Nb * w)

    def dist(a):
        return np.linalg.norm(V0 - a, axis=1)

    # busto: peso solo in base all'altezza (continuo anche tra parti diverse)
    if cfg.get("spine"):
        R = rot_x(-cfg["spine"])
        w = smoothstep_np(J["Waist"][1] - 0.04, J["Waist"][1] + 0.08, V0[:, 1])
        V, N = blend(V, _rot_about(V, J["Waist"], R), N, N @ R.T, w)
        for k in J:
            if J[k][1] > J["Waist"][1]:
                J[k] = _rot_about(J[k][None], J["Waist"], R)[0]
    for side, sgn in (("Right", 1), ("Left", -1)):
        arm = cfg.get("arm" + side[0], cfg.get("arm", (0, 0)))
        elbow = cfg.get("elbow" + side[0], cfg.get("elbow", 0))
        sh0 = np.array(m["J"][side + "Shoulder"])
        el0 = np.array(m["J"][side + "Elbow"])
        wr0 = np.array(m["J"][side + "Wrist"])
        sh = J[side + "Shoulder"]
        arm_parts = np.isin(part, [side + "UpperArm", side + "LowerArm", side + "Hand"])
        near_torso = np.isin(part, ["Torso"]) | arm_parts
        armpit = sh0[1] - 0.07
        lateral = smoothstep_np(abs(sh0[0]) - 0.04, abs(sh0[0]) + 0.012, V0[:, 0] * sgn)
        # sopra l'ascella: peso continuo in base alla distanza laterale; sotto: secondo la parte del corpo
        ws = np.where(V0[:, 1] > armpit, lateral, np.where(arm_parts, 1.0, 0.0))
        ws = np.where(near_torso, ws, 0.0)
        ws = np.where(V0[:, 1] > armpit, ws * smoothstep_np(armpit, armpit + 0.03, V0[:, 1]) + np.where(arm_parts, 1.0, 0.0) * (1 - smoothstep_np(armpit, armpit + 0.03, V0[:, 1])), ws)
        axis = normalize(wr0 - el0)
        t = (V0 - el0) @ axis
        we = np.where(arm_parts, smoothstep_np(-0.025, 0.02, t), 0.0)
        R1 = rot_x(arm[1]) @ rot_z(sgn * arm[0])
        V, N = blend(V, _rot_about(V, sh, R1), N, N @ R1.T, ws)
        el = _rot_about(J[side + "Elbow"][None], sh, R1)[0]
        R2 = rot_x(elbow)
        V, N = blend(V, _rot_about(V, el, R2), N, N @ R2.T, we)
    if cfg.get("head"):
        R = rot_x(cfg["head"])
        ny = m["J"]["Neck"][1]
        wh = np.where(np.isin(part, ["Head", "Torso"]), smoothstep_np(ny - 0.03, ny + 0.03, V0[:, 1]), 0.0)
        V, N = blend(V, _rot_about(V, J["Neck"], R), N, N @ R.T, wh)
    return V, N


def smoothstep_np(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def joints_world(m, height, position, yaw):
    R = rot_y(yaw)
    return {k: (np.array(v) * height) @ R.T + np.asarray(position) for k, v in m["J"].items()}


def add_titan(scene, m, height, position, yaw=0.0, pose="roar", tint=(1, 1, 1), amount=1.0):
    from engine import M_TEX
    V, N = posed(m, pose, amount)
    R = rot_y(yaw)
    Vw = (V * height) @ R.T + np.asarray(position)
    Nw = N @ R.T
    scene.texture = m["tex"]
    scene.add(Vw, m["F"], M_TEX, tint, N=Nw, UV=m["UV"])
    return Vw

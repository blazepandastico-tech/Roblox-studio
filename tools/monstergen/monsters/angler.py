"""Abyss Angler - deep ocean biome. Floating armoured angler fish with a glowing lure."""
from geo import Mesh, V, crystal, gem, hexc, hull, hull_sym, plate, project, spike, surface_plate, wedge_plate
from kit import Spine, both, eye, limb, teeth
from rig import Monster, key, mir, wave

BODY, BODY_L, BODY_D = hexc("#4540B5"), hexc("#7A74F0"), hexc("#28226A")
ARM, ARM_L, ARM_D = hexc("#2A2470"), hexc("#3D3696"), hexc("#191447")
BELLY, BELLY_L = hexc("#B3A5FA"), hexc("#D9D0FF")
FIN, FIN_L, FIN_D = hexc("#18B8C9"), hexc("#6BEAF0"), hexc("#0E8A9C")
BONE, BONE_L, BONE_D = hexc("#F4F0DC"), hexc("#FFFFFF"), hexc("#CFC8A8")
GLOW, GLOW_L = hexc("#5CFFD0"), hexc("#D0FFF2")
LURE, LURE_L = hexc("#FFF36B"), hexc("#FFFFFF")
DARK = hexc("#120E33")


def build() -> Monster:
    m = Monster(
        "AbyssAngler", "Abyss Angler", "Ocean (deep sea)", 14, "Uncommon", "scary",
        palette={"main": "#4540B5", "lighter facets": "#7A74F0", "armour plates": "#2A2470", "belly": "#B3A5FA", "fins": "#18B8C9",
                 "glow (spots, stripes)": "#5CFFD0", "glow (lure, eyes)": "#FFF36B", "trim (teeth, spikes)": "#F4F0DC"},
        scale=1.2, hover=1.8,
    )
    bd = lambda me, s: me.shade(BODY, BODY_L, BODY_D, seed=s)
    ar = lambda me, s: me.shade(ARM, ARM_L, ARM_D, seed=s)
    fin = lambda me, s: me.shade(FIN, FIN_L, FIN_D, seed=s, jitter=0.8)
    bone = lambda me, s: me.shade(BONE, BONE_L, BONE_D, seed=s)
    gl = lambda me, s: me.shade(GLOW, GLOW_L, GLOW, seed=s, jitter=0.9)
    bel = lambda me, s: me.shade(BELLY, BELLY_L, BELLY * 0.85, seed=s, jitter=0.6)

    # ---------------- body ----------------
    B = Spine(
        [(0, 5.2, -3.0), (0, 5.3, -2.2), (0, 5.35, -0.8), (0, 5.2, 0.8), (0, 5.05, 2.1), (0, 5.0, 3.1)],
        [(1.9, 1.7), (2.5, 2.6), (2.75, 3.0), (2.2, 2.5), (1.4, 1.7), (0.8, 1.0)],
        n=10, roll=90, profile=[1.1, 1, 1, 1, 0.97, 0.9, 0.97, 1, 1, 1], caps=(0.2, 0.4),
    )
    body = B.mesh()
    lip = hull_sym([(0, 5.7, -4.3), (1.8, 5.5, -3.7), (2.3, 5.2, -2.5), (0, 6.9, -3.2), (2.0, 6.6, -2.5), (0, 5.1, -3.9), (1.7, 5.0, -3.4), (2.4, 6.0, -1.8), (0, 7.6, -2.2)])
    spikes = B.spikes([0.5, 0.64, 0.78, 0.9], [1.5, 1.3, 1.05, 0.8], lean=0.6, thin=0.2, long=0.5)
    head_pl = both(B.plates(0.12, 0.46, 2, 104, 150, tilt=0.3, lift=0.26))
    side_pl = both(B.plates(0.5, 0.95, 4, 110, 160, tilt=0.4, lift=0.2))
    scutes = B.plates(0.2, 0.97, 6, 238, 302, tilt=0.2, lift=0.16)
    gill_l = Mesh.join([B.plate([(s, 176), (s + 0.035, 168), (s + 0.05, 200), (s + 0.015, 212)], lift=0.16, bevel=0.5) for s in (0.44, 0.5, 0.56)])
    chin_sp = B.spikes([0.36, 0.5, 0.64], [0.7, 0.9, 0.7], ang=270, lean=0.4, thin=0.2, long=0.4)
    up_teeth_l = teeth((-0.35, 5.25, -4.15), (-2.1, 5.15, -2.6), 6, 1.0, direction=(0, -1, 0.05), r=0.15, inset=0.15, big={0: 1.3, 2: 1.2})
    eh = project(lip, (-6, 6.35, -2.75), (0, 6.0, -2.4))
    sock_l, eye_l, pupil_l = eye(eh[0] + eh[1] * 0.06, (1.05, 0.85, 0.3), eh[1], n=6, pupil=0.34)
    brow_l = hull([(-1.2, 7.05, -3.3), (-2.55, 6.95, -2.3), (-2.6, 6.55, -2.0), (-2.2, 6.75, -3.0), (-1.3, 6.8, -3.5), (-2.0, 7.25, -2.5)])
    m.part("Body", bd(body + lip, "an.body") + bone(spikes + chin_sp, "an.sp") + ar(head_pl + side_pl + both(gill_l) + both(brow_l), "an.pl") + bel(scutes, "an.sc")
           + both(up_teeth_l).shade(BONE_L, BONE_L, BONE, seed="an.t").weight(0.5) + both(sock_l).paint(DARK).weight(0.5) + both(pupil_l).paint(DARK).weight(0),
           pivot=(0, 5.2, 0))
    m.part("Eyes", both(eye_l).shade(LURE, LURE_L, LURE, seed="an.eye"), (0, 5.2, 0), parent="Body", glow=True)
    spots_l = Mesh.join([gem(p[0] + p[1] * 0.04, (0.5 * k, 0.5 * k, 0.22), n=6, axis=p[1]) for p, k in
                         [(B.surf(s, a), k) for s, a, k in [(0.42, 196, 1.0), (0.52, 192, 1.15), (0.62, 190, 1.0), (0.72, 188, 0.9), (0.82, 186, 0.75), (0.92, 184, 0.6), (0.3, 205, 0.8)]] if p])
    stripes_l = Mesh.join([B.crack([(s, 150), (s + 0.02, 132), (s - 0.01, 116)], width=0.26) for s in (0.56, 0.68, 0.8)])
    throat = hull_sym([(0, 5.0, -3.3), (1.3, 4.95, -2.9), (1.6, 4.9, -1.6), (0, 4.75, -1.4), (0, 4.6, -2.4)])
    m.part("BodyGlow", gl(both(spots_l) + both(stripes_l), "an.glow") + throat.shade(hexc("#FF5FA8"), hexc("#FFA6D0"), hexc("#D93A86"), seed="an.throat"),
           (0, 5.2, 0), parent="Body", glow=True)

    # ---------------- jaw ----------------
    JP = (0, 4.5, -1.3)
    jaw = hull_sym([(0, 3.5, -4.7), (1.9, 3.8, -4.0), (2.45, 4.3, -2.2), (2.3, 3.2, -1.4), (0, 2.5, -2.6), (1.7, 4.75, -3.9), (0, 4.8, -4.6), (2.3, 4.8, -2.0), (1.4, 2.8, -3.6), (0, 3.4, -1.0)])
    low_teeth_l = teeth((-0.4, 4.7, -4.45), (-2.15, 4.7, -2.4), 6, 1.25, direction=(0, 1, 0.06), r=0.17, inset=0.2, big={1: 1.35, 3: 1.2})
    jaw_pl = surface_plate(jaw, [(-0.9, -4, -4.0), (0.9, -4, -4.0), (1.3, -4, -2.4), (0, -4, -1.7), (-1.3, -4, -2.4)], ("ray", (0, 1, 0)), lift=0.2, bevel=0.65)
    jaw_sp_l = spike((-2.2, 3.5, -1.9), (-3.1, 3.0, -1.2), 0.28, n=4) + spike((-1.5, 3.0, -3.4), (-2.0, 2.2, -3.6), 0.22, n=4)
    m.part("Jaw", bd(jaw, "an.jaw") + ar(jaw_pl, "an.jp") + bone(both(jaw_sp_l), "an.js")
           + both(low_teeth_l).shade(BONE_L, BONE_L, BONE, seed="an.t2").weight(0.5), pivot=JP, parent="Body")

    # ---------------- lure ----------------
    L0, L1, L2 = V(0, 7.9, -1.9), V(0, 10.0, -2.7), V(0, 10.9, -4.6)
    m.part("Lure1", bd(limb(L0 - V(0, 0.5, 0), L1, 0.34, 0.22, n=5, ext=(0.1, 0.15)), "an.l1"), L0, parent="Body")
    m.part("Lure2", bd(limb(L1, L2, 0.22, 0.14, n=5, ext=(0.15, 0.1)), "an.l2") + ar(limb(L2, L2 + V(0, -0.9, -0.5), 0.12, 0.1, n=4, ext=(0.05, 0.05)), "an.l3"), L1, parent="Lure1")
    orb = crystal(L2 + V(0, -2.5, -1.2), L2 + V(0, -0.7, -0.45), 0.62, n=6, waist=0.5)
    m.part("LureGlow", orb.shade(LURE, LURE_L, LURE, seed="an.orb", jitter=0.9), L1, parent="Lure2", glow=True)

    # ---------------- fins ----------------
    df = [V(0, 7.9, -0.6), V(0, 10.1, 0.6), V(0, 9.3, 1.3), V(0, 9.5, 2.2), V(0, 8.3, 2.6), V(0, 8.3, 3.3), V(0, 6.6, 3.0), V(0, 7.3, 0.6)]
    dorsal = wedge_plate(df, 0.5, 0.14, root=7)
    d_spines = Mesh.join([limb(V(0, 7.6, z0), V(0, y1, z1), 0.16, 0.05, n=4, ext=(0.05, 0.1)) for z0, y1, z1 in [(-0.3, 10.2, 0.6), (0.9, 9.6, 2.2), (2.0, 8.4, 3.3)]])
    m.part("DorsalFin", fin(dorsal, "an.df") + bone(d_spines, "an.ds"), (0, 7.6, 0.9), parent="Body")
    pf = [V(-2.3, 4.9, 0.0), V(-4.9, 5.6, 0.4), V(-4.5, 4.6, 1.2), V(-5.2, 3.8, 2.1), V(-4.0, 3.5, 2.2), V(-3.9, 2.7, 3.0), V(-2.5, 3.6, 1.6)]
    pfin = wedge_plate(pf, 0.55, 0.14, root=0)
    pf_sp = Mesh.join([limb(pf[0], q, 0.18, 0.05, n=4, ext=(0.05, 0.1)) for q in (pf[1], pf[3], pf[5])])
    m.sym("Fin{}", fin(pfin, "an.pf") + bd(pf_sp, "an.pfs"), pf[0], parent="Body")

    # ---------------- tail ----------------
    tp = [V(0, 5.0, 2.9), V(0, 4.95, 4.4), V(0, 4.9, 5.7)]
    T1 = Spine([tp[0], (tp[0] + tp[1]) / 2, tp[1]], [(0.9, 1.15), (0.78, 1.0), (0.6, 0.8)], n=8, roll=90, caps=(0.3, 0.3))
    m.part("Tail1", bd(T1.mesh(), "an.t1") + bone(T1.spikes([0.5], [0.7], lean=0.6), "an.t1s") + bel(T1.plates(0.1, 0.9, 2, 238, 302, lift=0.12), "an.t1b")
           + ar(both(T1.plates(0.1, 0.9, 2, 112, 160, lift=0.15, tilt=0.3)), "an.t1p"), tp[0], parent="Body")
    T2 = Spine([tp[1], (tp[1] + tp[2]) / 2, tp[2]], [(0.62, 0.82), (0.5, 0.66), (0.38, 0.5)], n=6, roll=90, caps=(0.25, 0.3))
    m.part("Tail2", bd(T2.mesh(), "an.t2") + bone(T2.spikes([0.5], [0.55], lean=0.6), "an.t2s") + ar(both(T2.plates(0.1, 0.9, 1, 112, 160, lift=0.13)), "an.t2p"), tp[1], parent="Tail1")
    tf = [V(0, 4.9, 5.4), V(0, 7.9, 8.2), V(0, 6.4, 7.6), V(0, 5.6, 7.9), V(0, 4.9, 7.2), V(0, 4.2, 7.9), V(0, 3.4, 7.6), V(0, 1.9, 8.2)]
    tfin = wedge_plate(tf, 0.5, 0.14, root=0)
    tf_sp = Mesh.join([limb(tf[0], q, 0.18, 0.05, n=4, ext=(0.05, 0.1)) for q in (tf[1], tf[3], tf[5], tf[7])])
    m.part("TailFin", fin(tfin, "an.tf") + bd(tf_sp, "an.tfs"), tp[2], parent="Tail2")

    _animations(m)
    m.fx(anim="Attack1", kind="burst", part="Jaw", offset=(0, 0.8, -2.6), dir=(0, 0, -1), t0=0.58, t1=0.64,
         colors=["#FFFFFF", "#B3A5FA", "#5CFFD0"], speed=14, spread=60, size=0.9, life=0.5, rate=320, gravity=-6, shake=0.5)
    m.fx(anim="Attack2", kind="burst", part="Lure2", offset=(0, -1.8, -3.2), dir=(0, 0, -1), t0=0.62, t1=0.95,
         colors=["#FFFFFF", "#FFF36B", "#5CFFD0"], speed=22, spread=180, size=0.8, life=0.45, rate=160, gravity=0, light=True, bolts=True)
    return m


def _animations(m: Monster):
    def swim(p, t, T, amp, fin_amp):
        p["Tail1"] = (0, amp * wave(t, T, -0.1), 0)
        p["Tail2"] = (0, amp * 1.3 * wave(t, T, -0.25), 0)
        p["TailFin"] = (0, amp * 1.6 * wave(t, T, -0.4), 0)
        f = (6 * wave(t, T, 0.2), 0.6 * fin_amp * wave(t, T, 0.3), -fin_amp * wave(t, T))
        p["FinL"], p["FinR"] = f, mir(f)
        p["DorsalFin"] = (0, 0, amp * 0.3 * wave(t, T, 0.1))

    def idle(t):
        b = wave(t, 3.0)
        p = {"Body": (1.5 * b, 2 * wave(t, 3.0, 0.3), 2 * wave(t, 3.0, 0.15), 0, 0.3 * b, 0),
             "Jaw": (-10 - 6 * wave(t, 1.5, 0.2), 0, 0),
             "Lure1": (4 * wave(t, 3.0, 0.1), 0, 5 * wave(t, 1.5)), "Lure2": (6 * wave(t, 3.0, -0.1), 0, 8 * wave(t, 1.5, -0.2))}
        swim(p, t, 3.0, 8, 14)
        return p

    def walk(t):
        T = 1.2
        p = {"Body": (-2, 4 * wave(t, T, 0.15), 3 * wave(t, T, 0.4), 0, 0.15 * wave(t, T / 2), 0),
             "Jaw": (-12 - 4 * wave(t, T), 0, 0),
             "Lure1": (8 + 3 * wave(t, T / 2), 0, 4 * wave(t, T)), "Lure2": (8 + 5 * wave(t, T / 2, -0.2), 0, 6 * wave(t, T, -0.2))}
        swim(p, t, T, 15, 22)
        return p

    def run(t):
        T = 0.6
        p = {"Body": (-9, 6 * wave(t, T, 0.15), 4 * wave(t, T, 0.4), 0, 0.12 * wave(t, T / 2), 0),
             "Jaw": (-30 - 6 * wave(t, T), 0, 0),
             "Lure1": (26 + 4 * wave(t, T), 0, 0), "Lure2": (22 + 6 * wave(t, T, -0.2), 0, 0)}
        swim(p, t, T, 24, 30)
        f = (-20, 30 + 8 * wave(t, T), -8 * wave(t, T))
        p["FinL"], p["FinR"] = f, mir(f)
        return p

    def chomp(t):
        # 0-0.42 pull back and open wide, 0.42-0.58 lunge, snap shut at 0.6, bounce, recover
        back = key(t, [(0, 0), (0.4, 1, "out"), (0.58, -1, "in"), (0.75, -0.7), (1.2, 0)])
        open_ = key(t, [(0, 0), (0.38, 1, "out"), (0.54, 1), (0.6, -0.08, "in"), (0.7, 0.1), (1.2, 0)])
        bk, fw = max(back, 0), max(-back, 0)
        p = {"Body": (9 * bk - 7 * fw, 0, 0, 0, 0.3 * bk - 0.2 * fw, 1.0 * bk - 3.2 * fw),
             "Jaw": (-10 - 52 * open_, 0, 0),
             "Lure1": (-14 * bk + 22 * fw, 0, 0), "Lure2": (-10 * bk + 26 * fw, 0, 0),
             "Tail1": (0, 14 * wave(t, 0.3) * fw, 0), "Tail2": (0, 20 * wave(t, 0.3, -0.2) * fw, 0), "TailFin": (0, 26 * wave(t, 0.3, -0.4) * fw, 0),
             "DorsalFin": (-8 * fw, 0, 0)}
        f = (0, -18 * bk + 34 * fw, 20 * bk - 14 * fw)
        p["FinL"], p["FinR"] = f, mir(f)
        return p

    def flash(t):
        # 0-0.5 lure rears back, 0.5-0.62 whips forward, 0.62-0.95 flash + body shudder, recover
        w = key(t, [(0, 0), (0.48, 1, "out"), (0.62, -1, "in"), (0.95, -1), (1.4, 0)])
        fl = key(t, [(0.58, 0), (0.64, 1, "out"), (0.95, 1), (1.1, 0)])
        bk, fw = max(w, 0), max(-w, 0)
        sh = fl * wave(t, 0.09)
        p = {"Body": (5 * bk - 6 * fw + sh, 2 * sh, 2.5 * sh, 0, 0.15 * bk, 0.4 * bk - 0.3 * fw),
             "Jaw": (-10 - 14 * bk - 30 * fl, 0, 0),
             "Lure1": (34 * bk - 30 * fw, 0, 6 * sh), "Lure2": (30 * bk - 34 * fw, 0, 8 * sh),
             "Tail1": (0, 6 * sh, 0), "Tail2": (0, 9 * sh, 0), "TailFin": (0, 12 * sh, 0), "DorsalFin": (0, 0, 5 * sh)}
        f = (0, 20 * fl, -24 * fl + 10 * bk)
        p["FinL"], p["FinR"] = f, mir(f)
        return p

    m.anim("Idle", "Idle (floating)", 3.0, True, idle, step=6, ground="none", note="Bobs up and down, jaw breathes, tail and fins sway, lure swings.")
    m.anim("Walk", "Swim (walk)", 1.2, True, walk, step=3, ground="none", note="Slow swim: tail wave travels from Tail1 to TailFin, pectoral fins paddle.")
    m.anim("Run", "Fast swim (run)", 0.6, True, run, step=2, ground="none", note="Charge: nose down, jaw open, fins swept back, fast tail beat.")
    m.anim("Attack1", "Abyss Chomp", 1.2, False, chomp, step=2, ground="none", note="Pulls back and opens wide (0-0.42 s), lunges forward and snaps shut (hit at 0.6 s).")
    m.anim("Attack2", "Lure Flash", 1.4, False, flash, step=2, ground="none", note="Lure rears back (0-0.5 s), whips forward and releases a blinding electric flash (0.62-0.95 s).")

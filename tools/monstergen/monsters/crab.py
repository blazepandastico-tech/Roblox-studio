"""Coral Crab - ocean biome. Wide armoured crab with giant claws and glowing coral on its shell."""
from geo import Mesh, V, crystal, gem, hexc, hull, hull_sym, spike, surface_plate, tube
from kit import both, crystal_cluster, limb, teeth
from rig import Monster, key, mir, wave

SHELL, SHELL_L, SHELL_D = hexc("#1F8FD6"), hexc("#5CC4F5"), hexc("#14609C")
PLATE, PLATE_L, PLATE_D = hexc("#165A9E"), hexc("#2477C4"), hexc("#0E3F73")
BELLY, BELLY_L = hexc("#FFE2B0"), hexc("#FFF3D6")
ACC, ACC_L, ACC_D = hexc("#FF8A3D"), hexc("#FFB870"), hexc("#D9611F")
CORAL, CORAL_L, CORAL_D = hexc("#FF5FA8"), hexc("#FFA6D0"), hexc("#D93A86")
CYAN, CYAN_L = hexc("#4DF0E4"), hexc("#B8FFF8")
EYE = hexc("#FFF27A")
DARK = hexc("#0B2540")
C = (0, 3.6, 0)  # shell centre used when projecting details


def build() -> Monster:
    m = Monster(
        "CoralCrab", "Coral Crab", "Ocean (reef)", 6, "Common", "cute but dangerous",
        palette={"shell": "#1F8FD6", "lighter facets": "#5CC4F5", "armour plates": "#165A9E", "belly": "#FFE2B0",
                 "trim (claw tips, leg tips, spikes)": "#FF8A3D", "coral": "#FF5FA8", "glow (coral crystals)": "#4DF0E4", "eyes": "#FFF27A"},
        scale=1.15,
    )
    sh = lambda me, s: me.shade(SHELL, SHELL_L, SHELL_D, seed=s)
    pl = lambda me, s: me.shade(PLATE, PLATE_L, PLATE_D, seed=s)
    acc = lambda me, s: me.shade(ACC, ACC_L, ACC_D, seed=s)
    cor = lambda me, s: me.shade(CORAL, CORAL_L, CORAL_D, seed=s, jitter=0.7)
    cy = lambda me, s: me.shade(CYAN, CYAN_L, CYAN, seed=s, jitter=0.9)

    # ---------------- body ----------------
    SX, SY, SZ = 1.2, 1.55, 1.25  # massive, tall dome
    O = (0, 3.0, 0)
    top = hull_sym([
        (0, 3.7, -2.5), (2.3, 3.6, -2.35), (3.9, 3.5, -0.7), (3.3, 3.5, 1.7), (1.7, 3.5, 2.4), (0, 3.6, 2.5),
        (0, 5.25, 0.1), (1.9, 4.95, -0.7), (1.9, 4.9, 1.0), (0, 4.85, -1.6), (3.0, 4.25, 0.2), (0, 4.75, 1.8),
        (3.6, 3.0, -0.6), (2.2, 2.9, -2.2), (3.0, 3.0, 1.5), (0, 2.9, -2.3), (0, 3.0, 2.3), (1.6, 3.0, 2.2),
    ]).scale((SX, SY, SZ), O)
    under = hull_sym([(0, 2.3, -1.9), (2.5, 2.7, -1.7), (3.2, 2.8, 0.2), (2.4, 2.7, 1.7), (0, 2.4, 2.0), (1.3, 1.9, 0.0), (0, 1.8, 0.2), (0, 3.3, 0), (2.5, 3.3, 0)]).scale((SX, 1.25, SZ), O)

    def top_plate(pts, **kw):
        return surface_plate(top, [(x * SX, 16, z * SZ) for x, z in pts], ("ray", (0, -1, 0)), **kw)

    plates = Mesh.join([
        top_plate([(-0.9, -0.9), (0.9, -0.9), (1.15, 0.5), (0, 1.15), (-1.15, 0.5)], lift=0.4, bevel=0.68),
        top_plate([(-0.85, -2.15), (0.85, -2.15), (0.95, -1.15), (-0.95, -1.15)], lift=0.3),
        top_plate([(-0.95, 1.4), (0.95, 1.4), (0.75, 2.25), (-0.75, 2.25)], lift=0.3),
    ])
    plates_l = Mesh.join([
        top_plate([(-1.15, -2.1), (-2.25, -2.0), (-3.0, -0.95), (-1.25, -1.05)], lift=0.32),
        top_plate([(-1.4, -0.8), (-3.4, -0.65), (-3.45, 0.65), (-1.5, 0.6)], lift=0.34),
        top_plate([(-1.3, 0.85), (-3.1, 0.95), (-2.5, 1.95), (-1.1, 2.1)], lift=0.32),
        top_plate([(-3.55, -0.5), (-3.8, -0.5), (-3.75, 0.5), (-3.5, 0.5)], lift=0.2),
    ])
    rim = []
    for x, z, dx, dz, k in [(-3.85, -0.7, -1, -0.15, 1.25), (-3.0, -1.6, -0.8, -0.6, 1.0), (-2.3, -2.35, -0.45, -1, 1.1), (-3.5, 0.6, -1, 0.3, 1.0),
                            (-3.2, 1.7, -0.8, 0.7, 0.95), (-1.7, 2.4, -0.3, 1, 0.85), (-0.9, -2.5, -0.1, -1, 0.75), (-0.6, 2.5, -0.1, 1, 0.7)]:
        x, z = x * SX, z * SZ
        rim.append(spike((x - 0.3 * dx, 3.75, z - 0.3 * dz), (x + dx * k, 3.95, z + dz * k), (0.36, 0.3), n=4, roll=45))
    rim_l = Mesh.join(rim)
    belly_plates = Mesh.join([surface_plate(under, [(-1.3, -6, z0), (1.3, -6, z0), (1.2, -6, z1), (-1.2, -6, z1)], ("ray", (0, 1, 0)), lift=0.14, bevel=0.75)
                              for z0, z1 in [(-1.7, -0.65), (-0.5, 0.5), (0.65, 1.7)]])
    coral_big = (crystal_cluster((-1.9, 5.9, 1.1), [((-0.25, 1, 0.15), 3.0, 0.62), ((-0.9, 1, 0.5), 2.1, 0.5), ((0.35, 1, 0.8), 1.9, 0.44), ((-0.6, 1, -0.6), 1.6, 0.4), ((-1.3, 1, -0.1), 1.3, 0.34)])
                 + crystal_cluster((2.1, 5.8, 0.3), [((0.35, 1, 0.1), 2.6, 0.58), ((1.0, 1, -0.3), 1.8, 0.46), ((0.1, 1, 0.8), 1.5, 0.4), ((0.9, 1, 0.7), 1.2, 0.32)])
                 + crystal_cluster((0.2, 5.9, 2.3), [((0, 1, 0.5), 2.0, 0.5), ((-0.6, 1, 0.9), 1.3, 0.36), ((0.7, 1, 0.8), 1.4, 0.36)]))
    barn = Mesh.join([spike((x * SX, y, z * SZ), (x * SX + dx, y + 0.6, z * SZ + dz), 0.34, n=5) for x, y, z, dx, dz in
                      [(-2.6, 4.85, -0.2, -0.15, 0), (2.5, 4.9, 1.0, 0.15, 0.05), (0.9, 5.8, -1.3, 0.05, -0.15), (-0.6, 5.75, -1.7, 0, -0.15), (2.6, 4.6, -1.0, 0.15, -0.1), (-2.9, 4.5, 1.2, -0.15, 0.1)]])
    m.part("Body", sh(top, "cr.top") + under.shade(BELLY, BELLY_L, BELLY * 0.85, seed="cr.un") + pl(plates + both(plates_l), "cr.pl")
           + acc(both(rim_l), "cr.rim") + belly_plates.shade(BELLY_L, BELLY_L, BELLY, seed="cr.bp") + cor(coral_big, "cr.coral") + acc(barn, "cr.barn").weight(0.6),
           pivot=(0, 3.6, 0))
    glow = (crystal_cluster((-0.5, 6.3, 0.2), [((0.2, 1, -0.2), 2.0, 0.44), ((-0.5, 1, -0.6), 1.4, 0.34), ((0.7, 1, 0.3), 1.2, 0.3)])
            + crystal_cluster((-3.1, 5.0, 1.2), [((-0.5, 1, 0.3), 1.4, 0.34), ((-1, 1, -0.2), 1.0, 0.28)])
            + crystal_cluster((2.9, 5.2, -1.1), [((0.5, 1, -0.3), 1.5, 0.36), ((1, 1, 0.3), 1.0, 0.28)])
            + crystal_cluster((1.2, 6.0, 1.9), [((0.3, 1, 0.5), 1.2, 0.3)])
            + crystal_cluster((-1.6, 5.6, -1.6), [((-0.3, 1, -0.5), 1.1, 0.3), ((0.3, 1, -0.8), 0.8, 0.24)]))
    m.part("ShellGlow", cy(glow, "cr.glow"), pivot=(0, 3.6, 0), parent="Body", glow=True)

    # ---------------- eyes & mouth ----------------
    EB = V(-1.0, 4.3, -2.85)
    stalk = tube([EB, EB + V(-0.1, 1.2, -0.4), EB + V(-0.15, 2.0, -0.65)], [0.4, 0.32, 0.4], n=5, roll=90, caps=(0.1, 0.15))
    ec = EB + V(-0.15, 2.15, -0.95)
    lid = hull([ec + V(-0.75, 0.15, 0.55), ec + V(0.75, 0.15, 0.55), ec + V(0, 0.85, 0.3), ec + V(-0.7, 0.35, -0.3), ec + V(0.7, 0.35, -0.3), ec + V(0, -0.1, 0.8)])
    m.sym("EyeStalk{}", sh(stalk, "cr.stalk") + pl(lid, "cr.lid"), EB, parent="Body")
    eg = gem(ec, (1.15, 1.0, 0.6), n=6, axis=(0, -0.1, -1))
    pupil = gem(ec + V(0, -0.03, -0.32), (0.26, 0.7, 0.14), n=4, axis=(0, -0.1, -1), table=0.3)
    m.sym("Eye{}", eg.shade(EYE, hexc("#FFFFFF"), EYE, seed="cr.eye") + pupil.paint(DARK), EB, parent="EyeStalk{}", glow=True)
    mand_l = hull([(-0.15, 3.05, -2.7), (-1.1, 3.05, -2.7), (-1.0, 2.2, -3.05), (-0.2, 1.95, -3.35), (-0.6, 2.9, -3.35), (-0.15, 2.4, -2.8)])
    fang_l = spike((-0.6, 2.2, -3.2), (-0.25, 1.45, -3.6), 0.2, n=4)
    m.part("Jaw", pl(both(mand_l), "cr.mand") + acc(both(fang_l), "cr.fang").weight(0.6), pivot=(0, 3.0, -2.7), parent="Body")

    # ---------------- big claws ----------------
    S, E, Wr = V(-3.1, 3.2, -2.5), V(-4.5, 3.7, -3.3), V(-4.65, 3.9, -4.6)
    up = limb(S, E, 0.95, 0.85, n=6, bulge=1.05, ext=(0.3, 0.3))
    up_sp = spike(E + V(-0.3, 0.3, 0.2), E + V(-1.2, 0.9, 0.6), 0.26, n=4)
    m.sym("Claw{}_Upper", sh(up, "cr.cu") + acc(up_sp, "cr.cus"), S, parent="Body")
    lo = limb(E, Wr, 0.88, 0.95, n=6, bulge=1.12, ext=(0.3, 0.3))
    lo_sp = spike((-5.2, 4.3, -3.9), (-6.1, 4.9, -3.7), 0.24, n=4) + spike((-4.5, 4.6, -3.9), (-4.5, 5.5, -3.6), 0.22, n=4)
    m.sym("Claw{}_Lower", sh(lo, "cr.cl") + acc(lo_sp, "cr.cls"), E, parent="Claw{}_Upper")
    palm = hull([(-5.6, 3.9, -4.5), (-3.7, 3.9, -4.5), (-4.65, 4.9, -4.5), (-4.65, 2.9, -4.5), (-6.1, 4.1, -5.8), (-3.3, 4.1, -5.8), (-4.7, 5.75, -5.8), (-4.7, 2.7, -5.7),
                 (-5.8, 4.6, -6.8), (-3.6, 4.6, -6.8), (-4.65, 5.65, -6.8), (-4.65, 3.75, -6.6)])
    finger = hull([(-5.5, 4.5, -6.6), (-3.8, 4.5, -6.6), (-4.65, 5.6, -6.6), (-4.65, 4.0, -6.7), (-5.1, 5.0, -8.2), (-4.2, 5.0, -8.2), (-4.65, 4.35, -8.3), (-4.65, 4.6, -9.5)])
    knuckles = Mesh.join([spike((-4.65 + dx, 5.5, z), (-4.65 + dx * 1.3, 6.1, z + 0.15), 0.24, n=4) for dx, z in [(-0.4, -5.3), (0.4, -5.9), (-0.3, -6.5)]])
    palm_plate = surface_plate(palm, [(-12, 4.9, -5.0), (-12, 5.1, -6.3), (-12, 3.9, -6.3), (-12, 3.5, -5.2)], ("ray", (1, 0, 0)), lift=0.2, bevel=0.65)
    f_teeth = teeth((-4.65, 4.35, -8.0), (-4.65, 4.0, -6.9), 4, 0.36, direction=(0, -1, 0), r=0.14, inset=0.1)
    m.sym("Claw{}_Hand", sh(palm, "cr.palm") + acc(finger + knuckles, "cr.fing") + pl(palm_plate, "cr.pp") + f_teeth.shade(BELLY_L, BELLY_L, BELLY, seed="cr.ft").weight(0.5), Wr, parent="Claw{}_Lower")
    pin = hull([(-5.3, 3.6, -5.9), (-4.0, 3.6, -5.9), (-4.65, 2.5, -6.0), (-4.65, 3.8, -6.4), (-5.0, 3.0, -7.8), (-4.3, 3.0, -7.8), (-4.65, 3.55, -7.9), (-4.65, 3.7, -9.3)])
    p_teeth = teeth((-4.65, 3.55, -7.8), (-4.65, 3.75, -6.8), 3, 0.32, direction=(0, 1, 0), r=0.13, inset=0.1)
    m.sym("Claw{}_Pincer", acc(pin, "cr.pin") + p_teeth.shade(BELLY_L, BELLY_L, BELLY, seed="cr.pt").weight(0.5), (-4.65, 3.4, -6.0), parent="Claw{}_Hand")

    # ---------------- walking legs ----------------
    for i, z in enumerate([-0.9, 0.55, 1.95]):
        hip, knee, ank, tip = V(-3.7, 3.1, z), V(-5.6, 4.7, z * 1.3), V(-6.9, 2.5, z * 1.6), V(-7.3, 0.0, z * 1.72)
        n = i + 1
        u_ = limb(hip, knee, 0.78, 0.64, n=6, bulge=0.86, ext=(0.3, 0.3))
        ksp = spike(knee + V(0.1, 0.2, 0), knee + V(-0.6, 1.3, 0.0), 0.32, n=4)
        m.sym(f"Leg{n}{{}}_Upper", sh(u_, f"cr.l{n}u") + acc(ksp, "cr.ks"), hip, parent="Body")
        l_ = limb(knee, ank, 0.64, 0.54, n=6, ext=(0.3, 0.25))
        band = surface_plate(l_, [(-14, 4.3, knee[2] - 0.5), (-14, 4.3, knee[2] + 0.5), (-14, 3.0, ank[2] + 0.5), (-14, 3.0, ank[2] - 0.5)], (knee + ank) / 2, lift=0.16)
        m.sym(f"Leg{n}{{}}_Lower", sh(l_, f"cr.l{n}l") + pl(band, "cr.lb"), knee, parent=f"Leg{n}{{}}_Upper")
        t_ = tube([ank, ank + (tip - ank) * 0.45, tip], [0.56, 0.42, 0.05], n=5, caps=(0.25, 0.02))
        m.sym(f"Leg{n}{{}}_Tip", acc(t_, f"cr.l{n}t"), ank, parent=f"Leg{n}{{}}_Lower")
    m.ground_parts = [f"Leg{n}{s}_Tip" for n in (1, 2, 3) for s in "LR"]

    _animations(m)
    m.fx(anim="Attack1", kind="burst", part="Body", offset=(0, -3.0, -7.5), dir=(0, 1, 0), t0=0.62, t1=0.7,
         colors=["#FFFFFF", "#8FE9FF", "#2FA8E8"], speed=16, spread=70, size=1.0, life=0.7, rate=350, gravity=28, shake=0.6)
    m.fx(anim="Attack2", kind="breath", part="ClawR_Hand", offset=(0, 0.3, -4.5), dir=(0, 0.05, -1), t0=0.5, t1=1.1,
         colors=["#FFFFFF", "#B8FFF8", "#4DF0E4"], speed=18, spread=12, size=0.9, life=0.8, rate=40, gravity=-4)
    return m


def _animations(m: Monster):
    def legs(p, t, T, swing, lift, crouch=0.0):
        for n in (1, 2, 3):
            for side in "LR":
                # tripod gait: L1 R2 L3 move together, then R1 L2 R3
                ph = 0.0 if ((n % 2 == 1) == (side == "L")) else 0.5
                s = wave(t, T, ph)
                air = max(0.0, wave(t, T, ph + 0.25))
                up = (0, swing * s * (1.0 if n != 2 else 0.8), -lift * air - crouch)
                lo = (0, 0, lift * 0.5 * air + crouch * 1.4)
                tp = (0, 0, lift * 0.35 * air)
                if side == "R":
                    up, lo, tp = mir(up), mir(lo), mir(tp)
                p[f"Leg{n}{side}_Upper"], p[f"Leg{n}{side}_Lower"], p[f"Leg{n}{side}_Tip"] = up, lo, tp

    def claws(p, up_l, lo_l, hand_l, pin_l, up_r=None, lo_r=None, hand_r=None, pin_r=None):
        p["ClawL_Upper"], p["ClawL_Lower"], p["ClawL_Hand"], p["ClawL_Pincer"] = up_l, lo_l, hand_l, pin_l
        p["ClawR_Upper"] = mir(up_l) if up_r is None else up_r
        p["ClawR_Lower"] = mir(lo_l) if lo_r is None else lo_r
        p["ClawR_Hand"] = mir(hand_l) if hand_r is None else hand_r
        p["ClawR_Pincer"] = mir(pin_l) if pin_r is None else pin_r

    def idle(t):
        b = wave(t, 3.0)
        p = {"Body": (1.0 * b, 0, 1.0 * wave(t, 3.0, 0.25), 0, 0.08 * b, 0),
             "EyeStalkL": (6 * wave(t, 1.5, 0.1), 0, 8 * wave(t, 3.0, 0.3)), "EyeStalkR": (6 * wave(t, 1.5, 0.45), 0, -8 * wave(t, 3.0, 0.6)),
             "Jaw": (-8 - 8 * wave(t, 0.75), 0, 0)}
        claws(p, (3 * b, 4 * wave(t, 3.0, 0.2), -4 * b), (0, 3 * b, 0), (2 * b, 0, 0), (-10 - 10 * wave(t, 1.5, 0.2), 0, 0),
              pin_r=(-10 - 10 * wave(t, 1.5, 0.7), 0, 0))
        for n in (1, 2, 3):
            for side in "LR":
                up = (0, 0, 1.5 * b)
                p[f"Leg{n}{side}_Upper"] = up if side == "L" else mir(up)
        return p

    def walk(t):
        T = 1.2
        p = {"Body": (0, 2 * wave(t, T), 2.5 * wave(t, T, 0.25), 0, 0, 0),
             "EyeStalkL": (5 * wave(t, T / 2), 0, 5), "EyeStalkR": (5 * wave(t, T / 2, 0.3), 0, -5), "Jaw": (-10, 0, 0)}
        claws(p, (4 * wave(t, T), 6 * wave(t, T, 0.1), -6), (0, 4 * wave(t, T, 0.2), 0), (0, 0, 0), (-14, 0, 0),
              up_r=mir((4 * wave(t, T, 0.5), 6 * wave(t, T, 0.6), -6)), lo_r=mir((0, 4 * wave(t, T, 0.7), 0)))
        legs(p, t, T, 16, 22)
        return p

    def run(t):
        T = 0.6
        p = {"Body": (-5, 3 * wave(t, T), 3.5 * wave(t, T, 0.25), 0, 0.12 * wave(t, T / 2), 0),
             "EyeStalkL": (-12 + 6 * wave(t, T), 0, 8), "EyeStalkR": (-12 + 6 * wave(t, T, 0.4), 0, -8), "Jaw": (-16, 0, 0)}
        snap = -18 - 16 * wave(t, T / 2)
        claws(p, (14, -6, -26 + 5 * wave(t, T)), (0, -8, 0), (10, 0, 0), (snap, 0, 0),
              up_r=mir((14, -6, -26 + 5 * wave(t, T, 0.5))), pin_r=mir((-18 - 16 * wave(t, T / 2, 0.5), 0, 0)))
        legs(p, t, T, 24, 30)
        return p

    def smash(t):
        # raise both claws (0-0.45 s), slam them down in front (hit 0.62 s), recover
        up = key(t, [(0, 0), (0.42, 1, "out"), (0.52, 1.05), (0.62, -0.35, "in"), (0.8, -0.2), (1.3, 0)])
        hit = key(t, [(0.58, 0), (0.64, 1, "out"), (0.9, 0.3), (1.3, 0)])
        u = max(up, 0)
        p = {"Body": (10 * up - 3 * hit, 0, 0, 0, 0.5 * u - 0.35 * hit, 0.3 * u - 0.4 * hit),
             "EyeStalkL": (-14 * u + 14 * hit, 0, 6 * u), "EyeStalkR": (-14 * u + 14 * hit, 0, -6 * u), "Jaw": (-10 - 22 * u, 0, 0)}
        claws(p, (52 * u + 16 * min(up, 0), -10 * u, -22 * u), (26 * u - 6 * hit, 0, 0), (18 * u - 6 * hit, 0, 0), (-10 - 32 * u + 30 * hit, 0, 0))
        for n in (1, 2, 3):
            for side in "LR":
                up_ = (0, 0, 7 * u - 6 * hit)
                lo_ = (0, 0, -6 * u + 7 * hit)
                p[f"Leg{n}{side}_Upper"] = up_ if side == "L" else mir(up_)
                p[f"Leg{n}{side}_Lower"] = lo_ if side == "L" else mir(lo_)
        return p

    def bubble(t):
        # right claw pulls back (0-0.4 s), thrusts forward open and fires bubbles (0.5-1.1 s), snaps shut, recovers
        back = key(t, [(0, 0), (0.38, 1, "out"), (0.5, -1, "out"), (1.1, -1), (1.5, 0)])
        fire = key(t, [(0.44, 0), (0.52, 1, "out"), (1.1, 1), (1.22, 0)])
        snap = key(t, [(1.1, 0), (1.2, 1, "in"), (1.5, 0)])
        bk, fw = max(back, 0), max(-back, 0)
        shake = fire * wave(t, 0.1)
        p = {"Body": (-3 * fw, -10 * bk + 12 * fw, -3 * fw, 0, -0.1 * fw, -0.5 * fw + 0.3 * bk),
             "EyeStalkL": (-8 * fw, 0, 4), "EyeStalkR": (-8 * fw, 0, -4), "Jaw": (-10 - 14 * fire, 0, 0)}
        claws(p, (4 * bk, 4 * bk, -8 * bk), (0, 0, 0), (0, 0, 0), (-12, 0, 0),
              up_r=(12 * fw - 6 * bk + shake, 30 * bk - 26 * fw, 10 * bk + 8 * fw), lo_r=(0, 26 * bk - 24 * fw, 0),
              hand_r=(6 * fw + 1.5 * shake, 10 * fw, 0), pin_r=(-12 - 30 * fire + 26 * snap, 0, 0))
        for n in (1, 2, 3):
            for side in "LR":
                up_ = (0, 0, 3 * fw)
                p[f"Leg{n}{side}_Upper"] = up_ if side == "L" else mir(up_)
        return p

    m.anim("Idle", "Idle (breathing)", 3.0, True, idle, step=6, note="Shell rises and falls, eye stalks wiggle, pincers open and close, mandibles chew.")
    m.anim("Walk", "Walk", 1.2, True, walk, step=3, ground="stick", note="Tripod gait: legs L1-R2-L3 step together, then R1-L2-R3. Claws sway.")
    m.anim("Run", "Run / charge", 0.6, True, run, step=2, ground="stick", note="Fast scuttle with both claws raised and snapping.")
    m.anim("Attack1", "Claw Smash", 1.3, False, smash, step=2, note="Raises both claws (0-0.5 s) and slams them down in front (hit at 0.62 s).")
    m.anim("Attack2", "Bubble Blast", 1.5, False, bubble, step=2, note="Pulls the right claw back, thrusts it forward open and fires bubbles (0.5-1.1 s), then snaps shut.")

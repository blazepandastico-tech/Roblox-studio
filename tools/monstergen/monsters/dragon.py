"""Magma Dragon - volcano biome. Massive four-legged winged beast with armour plates and lava cracks."""
from geo import Mesh, V, crack, hexc, hull, hull_sym, plate, project, spike, surface_plate
from kit import Spine, both, eye, horn, limb, limb_spine, teeth, toed_paw
from rig import Monster, key, mir, wave

RED, RED_L, RED_D = hexc("#D12B20"), hexc("#F65A3C"), hexc("#961C1F")
ARM, ARM_L, ARM_D = hexc("#7E1721"), hexc("#A8222B"), hexc("#571019")  # darker armour plates
BELLY, BELLY_L = hexc("#F9C76A"), hexc("#FFE39A")
BONE, BONE_L, BONE_D = hexc("#F6E8CC"), hexc("#FFF9EA"), hexc("#D8C097")
WING, WING_L, WING_D = hexc("#F58A2C"), hexc("#FFB347"), hexc("#DC6420")
WING_HI = hexc("#FFD27A")
LAVA, LAVA_L = hexc("#FF9A1F"), hexc("#FFE05A")
EYE = hexc("#FFF27A")
DARK = hexc("#2A1418")


def side(x, zy):
    """Hints seen from the side: [(z, y), ...] at a fixed x."""
    return [(x, y, z) for z, y in zy]


def build() -> Monster:
    m = Monster(
        "Dragon", "Magma Dragon", "Volcano", 10, "Common", "powerful and scary",
        palette={"main": "#D12B20", "lighter facets": "#F65A3C", "armour plates": "#7E1721", "belly scutes": "#F9C76A",
                 "glow (lava cracks, mouth)": "#FF9A1F / #FFE05A", "trim (horns, claws, spikes)": "#F6E8CC",
                 "eyes": "#FFF27A", "wing membrane": "#F58A2C"},
        scale=1.1,
    )
    red = lambda me, s: me.shade(RED, RED_L, RED_D, seed=s)
    bone = lambda me, s: me.shade(BONE, BONE_L, BONE_D, seed=s)
    arm = lambda me, s: me.shade(ARM, ARM_L, ARM_D, seed=s)
    belly = lambda me, s: me.shade(BELLY, BELLY_L, BELLY * 0.85, seed=s, jitter=0.6)
    lava = lambda me, s: me.shade(LAVA, LAVA_L, LAVA, seed=s, jitter=0.9)

    # ---------------- body ----------------
    B = Spine(
        [(0, 5.0, -3.1), (0, 5.15, -2.3), (0, 5.15, -1.2), (0, 5.0, 0.0), (0, 4.85, 1.2), (0, 4.75, 2.3), (0, 4.7, 3.2)],
        [(1.3, 1.35), (2.05, 2.1), (2.3, 2.25), (2.15, 2.05), (1.9, 1.8), (1.6, 1.55), (1.05, 1.1)],
        n=10, roll=90, profile=[1.12, 1, 1, 1, 0.95, 0.84, 0.95, 1, 1, 1], caps=(0.5, 0.35),
    )
    body = B.mesh()
    spikes = B.spikes([0.13, 0.29, 0.45, 0.61, 0.77, 0.92], [1.25, 1.6, 1.55, 1.3, 1.1, 0.85], lean=0.5, thin=0.22, long=0.46)
    plates_l = B.plates(0.08, 0.94, 6, 104, 152, tilt=0.4, lift=0.22, gap=0.1)
    scutes = B.plates(0.03, 0.98, 7, 236, 304, tilt=0.2, lift=0.15, gap=0.08)
    shoulder_l = B.plate([(0.1, 158), (0.2, 150), (0.31, 160), (0.33, 190), (0.22, 205), (0.1, 195)], lift=0.3, bevel=0.6)
    studs_l = B.studs([(0.42, 165), (0.5, 172), (0.58, 166), (0.66, 174), (0.74, 168), (0.46, 205), (0.6, 210), (0.72, 205)], size=0.34, lift=0.16)
    m.part("Body", red(body, "dr.body") + bone(spikes, "dr.sp") + arm(both(plates_l), "dr.pl") + belly(scutes, "dr.sc")
           + arm(both(shoulder_l), "dr.sh") + arm(both(studs_l), "dr.st").weight(0.5), pivot=(0, 5.0, 0.2))

    cr_l = Mesh.join([
        B.crack([(0.36, 176), (0.42, 188), (0.5, 180), (0.58, 196), (0.68, 184), (0.78, 198), (0.9, 186)], width=0.34),
        B.crack([(0.42, 188), (0.44, 212), (0.5, 224)], width=0.28),
        B.crack([(0.58, 196), (0.62, 218)], width=0.28),
        B.crack([(0.68, 184), (0.72, 160)], width=0.26),
        B.crack([(0.1, 99), (0.26, 96), (0.42, 100), (0.58, 96), (0.74, 100), (0.9, 97)], width=0.26, lift=0.1),
    ])
    m.part("BodyGlow", lava(both(cr_l), "dr.glow"), pivot=(0, 5.0, 0.2), parent="Body", glow=True)

    # ---------------- neck ----------------
    N1 = Spine([(0, 5.3, -2.5), (0, 6.2, -3.3), (0, 7.05, -4.0)], [1.55, 1.36, 1.2], n=8, roll=90, caps=(0.4, 0.3))
    n1 = (red(N1.mesh(), "dr.n1") + bone(N1.spikes([0.35, 0.75], [0.85, 0.75], lean=-0.35), "dr.n1s")
          + belly(N1.plates(0.1, 0.95, 3, 232, 308, lift=0.14, tilt=0.2), "dr.n1b") + arm(both(N1.plates(0.15, 0.95, 2, 108, 150, lift=0.18, tilt=0.3)), "dr.n1p"))
    m.part("Neck1", n1, pivot=(0, 5.5, -2.7), parent="Body")
    ncr = Mesh.join([N1.crack([(0.2, 172), (0.45, 190), (0.7, 176), (0.92, 192)], width=0.28), N1.crack([(0.45, 190), (0.55, 214)], width=0.24)])
    m.part("NeckGlow", lava(both(ncr), "dr.ng"), pivot=(0, 5.5, -2.7), parent="Neck1", glow=True)
    N2 = Spine([(0, 6.85, -3.8), (0, 7.6, -4.45), (0, 8.2, -4.95)], [1.22, 1.12, 1.02], n=8, roll=90, caps=(0.3, 0.3))
    n2 = (red(N2.mesh(), "dr.n2") + bone(N2.spikes([0.5], [0.7], lean=-0.35), "dr.n2s")
          + belly(N2.plates(0.1, 0.95, 2, 232, 308, lift=0.13, tilt=0.2), "dr.n2b") + arm(both(N2.plates(0.15, 0.9, 1, 108, 150, lift=0.16)), "dr.n2p"))
    m.part("Neck2", n2, pivot=(0, 6.95, -3.9), parent="Neck1")

    # ---------------- head ----------------
    HP = (0, 8.1, -4.85)
    cranium = hull_sym([(0, 8.55, -4.15), (1.15, 9.05, -4.45), (1.38, 7.95, -4.4), (1.5, 8.4, -5.3), (1.1, 9.35, -5.35),
                        (0, 9.45, -5.0), (0.8, 9.0, -6.25), (0, 9.1, -6.35), (1.0, 7.9, -6.0)])
    muzzle = hull_sym([(0.92, 8.8, -5.9), (0, 8.95, -5.9), (0.98, 7.86, -5.7), (0.66, 8.5, -8.0), (0, 8.64, -8.15),
                       (0.7, 7.95, -8.3), (0, 8.2, -8.55), (0.84, 7.84, -7.0)])
    brow_l = hull([(-0.5, 9.22, -6.15), (-1.7, 9.55, -5.0), (-1.75, 9.15, -4.85), (-1.5, 8.98, -5.95), (-0.55, 8.98, -6.35), (-1.2, 9.62, -5.35)])
    horn_l = horn((-0.75, 9.1, -4.7), (-1.45, 10.6, -4.0), (-1.25, 11.8, -2.4), 0.54, n=6, k=7)
    horn2_l = horn((-1.2, 8.7, -4.5), (-2.15, 9.0, -3.9), (-2.5, 9.85, -2.95), 0.33, n=5, k=5)
    cheek_l = (spike((-1.35, 8.1, -4.6), (-2.3, 7.9, -3.6), 0.27, n=4, roll=45) + spike((-1.3, 7.98, -5.15), (-2.05, 7.6, -4.5), 0.21, n=4, roll=45))
    nose_horn = spike((0, 8.5, -7.65), (0, 9.3, -7.3), (0.2, 0.32), n=4)
    frill = spike((0, 9.4, -4.95), (0, 10.1, -4.3), (0.17, 0.42), n=4) + spike((0, 9.25, -5.6), (0, 9.75, -5.2), (0.14, 0.34), n=4)
    nostril_l = spike((-0.38, 8.5, -8.1), (-0.5, 8.85, -7.85), 0.15, n=4, roll=45)
    cheek_plate_l = surface_plate(cranium, side(-4, [(-4.6, 8.75), (-5.15, 8.45), (-4.9, 8.05), (-4.5, 8.2)]), ("ray", (1, 0, 0)), lift=0.14, bevel=0.6)
    snout_plate = surface_plate(muzzle, [(-0.55, 12, -6.3), (0.55, 12, -6.3), (0.42, 12, -7.35), (-0.42, 12, -7.35)], ("ray", (0, -1, 0)), lift=0.13, bevel=0.65)
    up_teeth_l = teeth((-0.56, 7.98, -8.15), (-0.92, 7.9, -6.0), 6, 0.6, direction=(0, -1, 0), r=0.11, inset=0.12, big={0: 1.6})
    eh = project(cranium, (-4, 8.78, -5.78), (0, 8.6, -5.3))
    sock_l, eye_l, pupil_l = eye(eh[0] + eh[1] * 0.05, (0.74, 0.44, 0.24), eh[1], n=6)
    head = (red(cranium + muzzle, "dr.head") + arm(both(brow_l) + both(cheek_plate_l) + snout_plate, "dr.brow")
            + bone(both(horn_l + horn2_l + cheek_l) + nose_horn + frill, "dr.horn")
            + both(nostril_l).paint(DARK).weight(0.4) + both(sock_l).paint(DARK).weight(0.5) + both(pupil_l).paint(DARK).weight(0)
            + both(up_teeth_l).shade(BONE_L, BONE_L, BONE, seed="dr.t").weight(0.45))
    m.part("Head", head, pivot=HP, parent="Neck2")
    m.part("Eyes", both(eye_l).shade(EYE, hexc("#FFFFFF"), EYE, seed="dr.eye"), pivot=HP, parent="Head", glow=True)

    JP = (0, 7.85, -4.9)
    jaw = hull_sym([(1.12, 7.8, -4.6), (1.18, 7.3, -4.8), (0.78, 7.0, -6.2), (0.42, 7.3, -8.0), (0.45, 7.72, -8.1), (0.8, 7.84, -6.2), (0, 6.9, -5.8), (0, 7.15, -8.2)])
    chin = spike((0, 7.05, -7.4), (0, 6.4, -6.95), (0.18, 0.3), n=4) + spike((0, 6.95, -6.4), (0, 6.5, -6.0), (0.14, 0.24), n=4)
    jaw_spike_l = spike((-1.05, 7.3, -4.9), (-1.75, 7.0, -4.2), 0.2, n=4, roll=45)
    low_teeth_l = teeth((-0.32, 7.7, -7.95), (-0.68, 7.8, -6.2), 5, 0.52, direction=(0, 1, 0), r=0.1, inset=0.12, big={1: 1.45})
    m.part("Jaw", arm(jaw, "dr.jaw") + bone(chin + both(jaw_spike_l), "dr.chin")
           + both(low_teeth_l).shade(BONE_L, BONE_L, BONE, seed="dr.t2").weight(0.45), pivot=JP, parent="Head")
    tongue = hull_sym([(0.55, 7.86, -5.2), (0.36, 7.87, -7.5), (0, 8.02, -6.5), (0, 7.97, -5.1), (0, 7.9, -7.8)])
    m.part("MouthGlow", lava(tongue, "dr.mouth"), pivot=JP, parent="Jaw", glow=True)

    # ---------------- legs ----------------
    def leg(tag, hip, knee, ankle, r, foot, plate_zy, crack_zy, spur):
        U = limb_spine(hip + V(0.3, 0.35, 0), knee, r[0], r[1], n=7, bulge=r[0] * 1.05, ext=(0.35, 0.3), at=0.3)
        L = limb_spine(knee, ankle, r[1] * 0.98, r[2], n=6, ext=(0.3, 0.25))
        um, lm = U.mesh(), L.mesh()
        pl = surface_plate(um, side(-9, plate_zy), U.path, lift=0.26, bevel=0.62)
        ks = spike(knee + V(0, 0.1, 0.25), knee + V(-0.25, 0.55, 1.35), 0.3, n=4, roll=45)
        shin = surface_plate(lm, [(-9, knee[1] - 0.25, knee[2] - 0.55), (-9, knee[1] - 0.3, knee[2] + 0.2), (-9, ankle[1] + 0.35, ankle[2] + 0.3), (-9, ankle[1] + 0.3, ankle[2] - 0.45)], L.path, lift=0.16, bevel=0.6)
        ft, cl = toed_paw(tuple(ankle), foot[0], foot[1], toes=3, claw=0.75, spur=spur)
        m.sym(f"Leg{tag}{{}}_Upper", red(um, "dr.lu" + tag) + arm(pl, "dr.lp" + tag) + bone(ks, "dr.ks"), hip, parent="Body")
        m.sym(f"Leg{tag}{{}}_Glow", lava(crack(um, side(-9, crack_zy), toward=U.path, width=0.28), "dr.lg" + tag), hip, parent=f"Leg{tag}{{}}_Upper", glow=True)
        m.sym(f"Leg{tag}{{}}_Lower", red(lm, "dr.ll" + tag) + arm(shin, "dr.shin" + tag), knee, parent=f"Leg{tag}{{}}_Upper")
        m.sym(f"Paw{tag}{{}}", red(ft, "dr.pw" + tag) + bone(cl, "dr.cl").weight(0.7), ankle, parent=f"Leg{tag}{{}}_Lower")

    leg("F", V(-1.9, 4.7, -1.9), V(-2.5, 2.85, -1.25), V(-2.5, 1.05, -1.85), (1.2, 0.8, 0.62), (1.75, 1.95),
        [(-2.7, 5.0), (-1.3, 5.2), (-0.9, 4.2), (-1.4, 3.5), (-2.5, 3.7)], [(-2.3, 3.5), (-1.9, 3.1), (-2.1, 2.7), (-1.6, 2.4)], False)
    leg("B", V(-1.65, 4.6, 2.25), V(-2.4, 2.9, 1.35), V(-2.4, 1.1, 2.55), (1.42, 0.86, 0.62), (1.85, 2.05),
        [(1.2, 5.1), (2.9, 5.0), (3.1, 4.0), (2.3, 3.4), (1.2, 3.8)], [(1.3, 3.6), (1.8, 3.2), (1.5, 2.8), (2.0, 2.4)], True)
    m.ground_parts = ["PawFL", "PawFR", "PawBL", "PawBR"]

    # ---------------- wings ----------------
    S, E, W = V(-1.2, 6.75, -1.2), V(-4.4, 10.0, -0.4), V(-7.4, 11.3, 0.3)
    F1, F2, F3, F4 = V(-10.0, 9.7, 1.9), V(-9.1, 7.2, 3.6), V(-7.1, 5.6, 4.6), V(-5.0, 5.1, 4.9)
    T1, Bq = V(-3.3, 5.5, 4.0), V(-1.35, 6.0, 1.9)
    arm_ = limb(S, E, 0.55, 0.42, n=6, ext=(0.35, 0.25))
    inner = plate([S, E + V(0, -0.1, 0), T1, Bq], 0.12, fan=0)
    strut = limb(E, T1, 0.2, 0.07, n=4, ext=(0.05, 0.1))
    espike = spike(E, E + V(0.25, 1.05, -0.6), 0.24, n=4, roll=45)
    m.sym("Wing{}_Upper", red(arm_ + strut, "dr.wa") + inner.shade(WING_L, WING_HI, WING, seed="dr.wi", jitter=0.7) + bone(espike, "dr.we"), S, parent="Body")
    fore = limb(E, W, 0.42, 0.32, n=6, ext=(0.25, 0.2))
    fingers = Mesh.join([limb(W, f, 0.22, 0.06, n=4, ext=(0.05, 0.12)) for f in (F1, F2, F3, F4)])

    def sc(a, b, k=0.2, c=W):
        return (a + b) / 2 + (c - (a + b) / 2) * k

    outer = plate([W, F1, sc(F1, F2), F2, sc(F2, F3), F3, sc(F3, F4), F4, sc(F4, T1, 0.16, E), T1 + V(0.2, 0.12, -0.1), E + V(0.3, -0.35, 0.1)], 0.18, fan=0)
    wclaw = spike(W, W + V(-0.45, 1.15, -0.95), 0.24, n=4, roll=45) + spike(W + V(0.2, 0, 0), W + V(0.1, 0.8, -1.0), 0.16, n=4, roll=45)
    m.sym("Wing{}_Lower", red(fore + fingers, "dr.wf") + outer.shade(WING_L, WING_HI, WING, seed="dr.wo", jitter=0.9) + bone(wclaw, "dr.wc"), E, parent="Wing{}_Upper")

    # ---------------- tail ----------------
    tp = [V(0, 4.75, 2.9), V(0, 4.4, 4.9), V(0, 3.9, 6.8), V(0, 3.45, 8.5), V(0, 3.15, 10.0), V(0, 3.05, 11.3)]
    tr = [1.42, 1.14, 0.88, 0.66, 0.48, 0.32]
    prev = "Body"
    for i in range(5):
        T = Spine([tp[i], (tp[i] + tp[i + 1]) / 2, tp[i + 1]], [tr[i], (tr[i] + tr[i + 1]) / 2 * 1.05, tr[i + 1]], n=8 if i < 3 else 6, roll=90, caps=(0.3, 0.35))
        mesh = (red(T.mesh(), f"dr.t{i}") + bone(T.spikes([0.3, 0.72], [1.0 - i * 0.14, 0.9 - i * 0.14], lean=0.55, thin=0.22, long=0.44), f"dr.ts{i}")
                + belly(T.plates(0.05, 0.95, 2, 236, 304, lift=0.13, tilt=0.2), f"dr.tb{i}")
                + arm(both(T.plates(0.08, 0.92, 2, 108, 152, lift=0.16, tilt=0.35)), f"dr.tp{i}"))
        if i == 4:
            blade = hull_sym([(0, 3.05, 10.9), (1.15, 3.0, 12.1), (0, 3.02, 13.6), (0, 3.5, 12.0), (0, 2.58, 12.0)])
            barb_l = spike((-0.5, 3.03, 11.4), (-1.5, 3.0, 10.7), (0.2, 0.3), n=4)
            mesh = mesh + bone(blade + both(barb_l), "dr.blade")
        m.part(f"Tail{i + 1}", mesh, tp[i], parent=prev)
        prev = f"Tail{i + 1}"
    tglow = (hull_sym([(0, 3.56, 11.5), (0.36, 3.42, 12.05), (0, 3.62, 12.8), (0, 3.3, 12.1)])
             + hull_sym([(0, 2.52, 11.5), (0.36, 2.64, 12.05), (0, 2.46, 12.8), (0, 2.78, 12.1)]))
    m.part("TailGlow", lava(tglow, "dr.tg"), tp[4], parent="Tail5", glow=True)

    _animations(m)
    m.fx(anim="Attack1", kind="breath", part="Head", offset=(0, 0.1, -3.6), dir=(0, -0.12, -1), t0=0.62, t1=1.35,
         colors=["#FFE05A", "#FF9A1F", "#E0331C"], speed=26, spread=16, size=1.6, life=0.6, rate=70, light=True)
    m.fx(anim="Attack2", kind="burst", part="Body", offset=(0, -4.8, -4.0), dir=(0, 1, 0), t0=0.78, t1=0.84,
         colors=["#FFE05A", "#FF9A1F", "#5A4034"], speed=16, spread=80, size=1.1, life=0.65, rate=400, gravity=30, shake=0.7)
    return m


def _legs(pose, tag, side_l, side_r):
    pose[f"Leg{tag}L_Upper"], pose[f"Leg{tag}L_Lower"], pose[f"Paw{tag}L"] = side_l
    pose[f"Leg{tag}R_Upper"], pose[f"Leg{tag}R_Lower"], pose[f"Paw{tag}R"] = side_r


def _step(t, T, phase, swing, lift, front=True):
    """One leg of a walk cycle: (upper, lower, paw) rotations about X."""
    s = wave(t, T, phase)
    c = max(0.0, wave(t, T, phase + 0.25))  # foot in the air while it swings forward
    up = swing * s
    lo = (-lift if front else lift) * c
    return (up, 0, 0), (lo, 0, 0), (-(up + lo) * 0.85, 0, 0)


def _animations(m: Monster):
    NT = 5

    def tail(t, T, amp, base_pitch=0.0, phase=0.0):
        return {f"Tail{i + 1}": (base_pitch + amp * 0.22 * wave(t, T / 2, phase - 0.12 * i), amp * (0.6 + 0.22 * i) * wave(t, T, phase - 0.13 * i), 0) for i in range(NT)}

    def idle(t):
        b = wave(t, 3.0)
        p = {
            "Body": (1.0 * b, 0, 0, 0, 0.06 * b, 0),
            "Neck1": (2.5 * wave(t, 3.0, -0.1), 3 * wave(t, 3.0, 0.2), 0),
            "Neck2": (2.0 * wave(t, 3.0, -0.2), 4 * wave(t, 3.0, 0.15), 0),
            "Head": (-2.5 * wave(t, 3.0, -0.25), 7 * wave(t, 3.0, 0.1), 2 * wave(t, 3.0, 0.3)),
            "Jaw": (-4 - 3 * wave(t, 1.5, 0.1), 0, 0),
            "WingL_Upper": (0, 3 * wave(t, 3.0, 0.5), -5 * b - 2), "WingL_Lower": (0, 0, -6 * wave(t, 3.0, -0.12)),
        }
        p["WingR_Upper"], p["WingR_Lower"] = mir(p["WingL_Upper"]), mir(p["WingL_Lower"])
        p.update(tail(t, 3.0, 9))
        for tag in ("F", "B"):
            leg = ((-1.0 * b, 0, 0), (0, 0, 0), (0, 0, 0))
            _legs(p, tag, leg, leg)
        return p

    def walk(t):
        T = 1.2
        p = {
            "Body": (1.5 * wave(t, T / 2, 0.1), 2.5 * wave(t, T), 1.5 * wave(t, T, 0.25), 0, 0, 0),
            "Neck1": (-3 + 2 * wave(t, T / 2, 0.3), -1.5 * wave(t, T), 0),
            "Neck2": (2 * wave(t, T / 2, 0.4), -1.5 * wave(t, T), 0),
            "Head": (2 - 2 * wave(t, T / 2, 0.5), 0, -1.5 * wave(t, T, 0.25)),
            "Jaw": (-4, 0, 0),
            "WingL_Upper": (0, 6, 10 - 4 * wave(t, T / 2, 0.2)), "WingL_Lower": (0, 4, 6 * wave(t, T / 2, 0.05)),
        }
        p["WingR_Upper"], p["WingR_Lower"] = mir(p["WingL_Upper"]), mir(p["WingL_Lower"])
        _legs(p, "F", _step(t, T, 0.0, 22, 30), _step(t, T, 0.5, 22, 30))
        _legs(p, "B", _step(t, T, 0.5, 20, 28, front=False), _step(t, T, 0.0, 20, 28, front=False))
        p.update(tail(t, T, 10, phase=0.3))
        return p

    def run(t):
        T = 0.6
        p = {
            "Body": (-4 + 5 * wave(t, T, 0.1), 0, 0, 0, 0.3 * max(0.0, wave(t, T, 0.35)), 0),
            "Neck1": (-14 - 3 * wave(t, T, 0.2), 0, 0),
            "Neck2": (-8 - 2 * wave(t, T, 0.3), 0, 0),
            "Head": (12 + 3 * wave(t, T, 0.45), 0, 0),
            "Jaw": (-12 - 5 * wave(t, T, 0.2), 0, 0),
            "WingL_Upper": (0, 22, 4 - 18 * wave(t, T, 0.15)), "WingL_Lower": (0, 12, -4 - 16 * wave(t, T, 0.0)),
        }
        p["WingR_Upper"], p["WingR_Lower"] = mir(p["WingL_Upper"]), mir(p["WingL_Lower"])
        _legs(p, "F", _step(t, T, 0.0, 34, 42), _step(t, T, 0.12, 34, 42))
        _legs(p, "B", _step(t, T, 0.5, 32, 40, front=False), _step(t, T, 0.62, 32, 40, front=False))
        p.update(tail(t, T, 5, base_pitch=3))
        return p

    def fire_breath(t):
        # 0.0-0.55 rear back and inhale, 0.55-0.7 lunge, 0.7-1.3 breathe fire, 1.3-1.7 recover
        rear = key(t, [(0, 0), (0.5, 1), (0.6, 1), (0.72, -1, "out"), (1.3, -1), (1.7, 0)])
        fire = key(t, [(0.58, 0), (0.72, 1, "out"), (1.3, 1), (1.5, 0)])
        shake = fire * wave(t, 0.12)
        up, dn = max(rear, 0), min(rear, 0)
        p = {
            "Body": (4 * up + 5 * dn, 0, 0, 0, 0.12 * up - 0.2 * fire, -0.25 * fire + 0.2 * up),
            "Neck1": (16 * up + 22 * dn, 2 * shake, 0),
            "Neck2": (12 * up + 16 * dn, 2 * shake, 0),
            "Head": (10 * up + 14 * fire, 3 * shake, 0),
            "Jaw": (-4 - 34 * fire - 6 * up, 0, 0),
            "WingL_Upper": (0, -8 * fire, -18 * up - 26 * fire + 3 * shake), "WingL_Lower": (0, 0, -8 * up - 14 * fire),
        }
        p["WingR_Upper"], p["WingR_Lower"] = mir(p["WingL_Upper"]), mir(p["WingL_Lower"])
        lg = ((-4 * up - 5 * dn, 0, 0), (0, 0, 0), (0, 0, 0))
        _legs(p, "F", lg, lg)
        _legs(p, "B", lg, lg)
        for i in range(NT):
            p[f"Tail{i + 1}"] = (-6 * fire - 4 * up, (4 + 2 * i) * shake, 0)
        return p

    def stomp(t):
        # 0-0.5 rear up on the hind legs, 0.5-0.7 hang, 0.7-0.8 slam down, 0.8-1.4 recover
        up = key(t, [(0, 0), (0.48, 1, "out"), (0.66, 1.05), (0.78, -0.2, "in"), (0.95, 0.06), (1.4, 0)])
        hit = key(t, [(0.74, 0), (0.8, 1, "out"), (1.0, 0.3), (1.4, 0)])
        u = max(up, 0)
        p = {
            "Body": (30 * up, 0, 0, 0, 1.0 * u - 0.2 * hit, 0.5 * u),
            "Neck1": (-16 * u + 8 * hit, 0, 0),
            "Neck2": (-10 * u + 6 * hit, 0, 0),
            "Head": (-8 * u - 10 * hit, 0, 0),
            "Jaw": (-5 - 26 * u - 8 * hit, 0, 0),
            "WingL_Upper": (0, -10 * u, -30 * u + 28 * hit), "WingL_Lower": (0, 0, -18 * u + 22 * hit),
        }
        p["WingR_Upper"], p["WingR_Lower"] = mir(p["WingL_Upper"]), mir(p["WingL_Lower"])
        fl = ((34 * u - 14 * hit, 0, -6 * u), (-48 * u + 10 * hit, 0, 0), (26 * u, 0, 0))
        _legs(p, "F", fl, tuple(mir(x) for x in fl))
        bk = ((-30 * up, 0, 0), (8 * u, 0, 0), (-8 * u, 0, 0))
        _legs(p, "B", bk, bk)
        for i in range(NT):
            p[f"Tail{i + 1}"] = (-(24 - 3 * i) * u + 8 * hit, 0, 0)
        return p

    m.anim("Idle", "Idle (breathing)", 3.0, True, idle, step=6, note="Breathing, slow tail sway, small head turn, wings rise and fall.")
    m.anim("Walk", "Walk", 1.2, True, walk, step=3, ground="stick", note="Diagonal pairs of legs step together; body sways, tail follows.")
    m.anim("Run", "Run / charge", 0.6, True, run, step=2, note="Gallop: front pair then hind pair, neck stretched low, wings beating.")
    m.anim("Attack1", "Fire Breath", 1.7, False, fire_breath, step=2, note="Rears back (0-0.55 s), lunges and breathes fire with open jaw (0.62-1.35 s), recovers.")
    m.anim("Attack2", "Stomp Slam", 1.4, False, stomp, step=2, note="Rears up on the hind legs (0-0.66 s), slams both front paws down (hit at 0.78 s), recovers.")

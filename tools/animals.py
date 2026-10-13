"""30 blocky Roblox-style animals. Front faces +Z, feet on y = 0."""
import math

from core import Model, dark, light, mix

BLK = '#141414'


def quad(m, col, body=(3.0, 2.6, 4.6), leg=(1.5, 0.9), head=(2.4, 2.2, 2.2), hup=0.3, hfwd=0.5,
         legcol=None, round_body=False, round_head=False, ears='point', earcol=None, snout=(1.2, 0.8, 0.9),
         snoutcol=None, nose='#222222', mat='SmoothPlastic', headcol=None, eyes=True, neck=0.0, hoof=None):
    w, h, l = body
    ll, lw = leg
    legcol = legcol or col
    headcol = headcol or col
    earcol = earcol or col
    by = ll + h / 2
    if round_body:
        m.ball((0, by, 0), (w * 1.1, h * 1.1, l * 1.05), col, mat)
    else:
        m.box((0, by, 0), body, col, mat)
    for sx in (-1, 1):
        for sz in (-1, 1):
            x, z = sx * (w / 2 - lw / 2 - 0.05), sz * (l / 2 - lw / 2 - 0.15)
            m.box((x, ll / 2, z), (lw, ll, lw), legcol, mat)
            if hoof:
                m.box((x, 0.2, z), (lw + 0.05, 0.4, lw + 0.05), hoof, mat)
    hw, hh, hd = head
    hy = ll + h + hup + neck
    hz = l / 2 + hfwd
    if neck:
        m.box((0, ll + h + neck / 2 - 0.2, l / 2 - 0.4), (hw * 0.55, neck + 0.8, hw * 0.55), headcol, mat)
    if round_head:
        m.ball((0, hy, hz), (hw, hh, hd), headcol, mat)
    else:
        m.box((0, hy, hz), head, headcol, mat)
    fz = hz + hd / 2
    if snout:
        sw, sh, sd = snout
        scol = snoutcol or light(col, 0.35)
        m.box((0, hy - hh * 0.2, fz + sd / 2 - 0.15), snout, scol, mat)
        if nose:
            m.box((0, hy - hh * 0.2 + sh / 2 - 0.1, fz + sd - 0.1), (min(sw * 0.5, 0.6), 0.35, 0.25), nose, mat)
    if eyes:
        for s in (-1, 1):
            m.ball((s * hw * 0.27, hy + hh * 0.13, fz - 0.02), 0.42, BLK)
    ey = hy + hh / 2
    if ears == 'point':
        for s in (-1, 1):
            m.box((s * hw * 0.33, ey + 0.4, hz - 0.2), (0.7, 1.1, 0.4), earcol, mat, rot=(0, 0, s * -12))
    elif ears == 'round':
        for s in (-1, 1):
            m.ball((s * hw * 0.4, ey, hz - 0.2), (1.0, 1.0, 0.6), earcol, mat)
    elif ears == 'long':
        for s in (-1, 1):
            m.box((s * hw * 0.25, ey + 1.1, hz - 0.2), (0.6, 2.4, 0.4), earcol, mat, rot=(0, 0, s * -8))
    elif ears == 'floppy':
        for s in (-1, 1):
            m.box((s * (hw / 2 + 0.15), hy + hh * 0.1, hz - 0.2), (0.4, 1.4, 0.9), earcol, mat, rot=(0, 0, s * 8))
    return dict(hy=hy, hz=hz, hw=hw, hh=hh, hd=hd, fz=fz, ey=ey, top=ll + h, ll=ll, l=l, w=w, h=h, by=by)


def tail(m, c, kind, col, mat='SmoothPlastic'):
    z = -c['l'] / 2
    y = c['top'] - 0.4
    if kind == 'ball':
        m.ball((0, y, z - 0.3), 0.9, col, mat)
    elif kind == 'up':
        m.box((0, y + 0.6, z - 0.4), (0.45, 1.8, 0.45), col, mat, rot=(25, 0, 0))
    elif kind == 'long':
        m.box((0, y - 0.2, z - 1.1), (0.45, 0.45, 2.4), col, mat, rot=(-25, 0, 0))
    elif kind == 'bushy':
        m.ball((0, y - 0.3, z - 1.3), (1.4, 1.4, 3.0), col, mat, rot=(-20, 0, 0))
    elif kind == 'curl':
        m.box((0, y, z - 0.3), (0.35, 0.35, 0.7), col, mat)
        m.box((0, y + 0.45, z - 0.55), (0.35, 0.9, 0.35), col, mat)
    elif kind == 'tuft':
        m.box((0, y - 0.7, z - 0.3), (0.3, 2.2, 0.3), col, mat)
        m.ball((0, y - 1.9, z - 0.3), (0.7, 0.9, 0.7), BLK)


def mk_cat():
    m = Model('Cat')
    c = quad(m, '#f2a24d', body=(2.4, 2.2, 4.0), leg=(1.5, 0.7), head=(2.4, 2.0, 2.0), snout=(0.9, 0.6, 0.5),
             snoutcol='#fff0dc', nose='#ff7aa8')
    for z in (-1.2, 0, 1.2):
        m.box((0, c['top'] + 0.02, z), (1.8, 0.1, 0.3), '#b8631a')
    tail(m, c, 'long', '#f2a24d')
    m.box((0, c['top'] - 0.1, -c['l'] / 2 - 2.4), (0.5, 0.5, 0.5), '#b8631a')
    return m


def mk_dog():
    m = Model('Dog')
    c = quad(m, '#d3a56c', body=(2.6, 2.4, 4.4), leg=(1.7, 0.8), head=(2.4, 2.1, 2.1), ears='floppy',
             earcol='#6b4220', snout=(1.3, 0.9, 1.0), snoutcol='#f1d9b5', nose='#111111')
    m.box((0.6, c['hy'] + 0.7, c['fz'] - 0.2), (0.9, 0.6, 0.5), '#6b4220')
    m.box((0, c['hy'] - 1.0, c['fz'] + 0.7), (0.5, 0.2, 0.6), '#ff7aa8')
    tail(m, c, 'up', '#d3a56c')
    return m


def mk_bunny():
    m = Model('Bunny')
    c = quad(m, '#f4f1f8', body=(2.6, 2.4, 3.4), leg=(1.2, 0.9), head=(2.2, 1.9, 1.9), ears='none', round_body=True,
             round_head=True, snout=None)
    for s in (-1, 1):
        m.ball((s * 0.55, c['ey'] + 1.3, c['hz'] - 0.3), (0.8, 3.0, 0.5), '#f4f1f8', rot=(0, 0, s * -6))
        m.ball((s * 0.55, c['ey'] + 1.3, c['hz'] - 0.05), (0.4, 2.3, 0.3), '#ffb7d5', rot=(0, 0, s * -6))
    m.ball((0, c['hy'] - 0.35, c['fz'] + 0.05), 0.45, '#ff7aa8')
    m.box((0, c['hy'] - 0.85, c['fz'] - 0.1), (0.45, 0.45, 0.2), '#ffffff')
    m.ball((0, c['top'] - 0.6, -c['l'] / 2 - 0.2), 1.3, '#ffffff')
    return m


def mk_pig():
    m = Model('Pig')
    c = quad(m, '#ffa9c6', body=(3.0, 2.6, 4.2), leg=(1.2, 0.9), head=(2.4, 2.2, 2.0), ears='floppy',
             earcol='#ff86ad', round_body=True, snout=(1.4, 1.0, 0.6), snoutcol='#ff86ad', nose=None)
    for s in (-1, 1):
        m.box((s * 0.3, c['hy'] - 0.45, c['fz'] + 0.5), (0.25, 0.4, 0.2), '#7a2a47')
    tail(m, c, 'curl', '#ff86ad')
    return m


def mk_cow():
    m = Model('Cow')
    c = quad(m, '#f5f5f5', body=(3.2, 3.0, 5.0), leg=(1.8, 1.0), head=(2.4, 2.2, 2.2), ears='none',
             snout=(1.7, 1.0, 0.9), snoutcol='#ffb3c1', nose='#aa5566', hoof='#2a2a2a')
    for p in [(-0.9, c['top'] + 0.03, 0.8, 1.2, 1.4), (0.9, c['top'] + 0.03, -1.0, 1.4, 1.2)]:
        m.box((p[0], p[1], p[2]), (p[3], 0.08, p[4]), BLK)
    m.box((c['w'] / 2 + 0.03, 3.2, 0.5), (0.08, 1.4, 1.5), BLK)
    m.box((-c['w'] / 2 - 0.03, 3.4, -0.9), (0.08, 1.5, 1.3), BLK)
    for s in (-1, 1):
        m.box((s * 0.9, c['ey'] + 0.3, c['hz']), (0.35, 0.7, 0.35), '#e8dcc0', rot=(0, 0, s * -15))
        m.box((s * 1.55, c['hy'] + 0.4, c['hz'] - 0.2), (0.9, 0.35, 0.6), '#f5f5f5')
    m.box((0.4, c['hy'] + 0.55, c['fz'] - 0.1), (0.9, 0.7, 0.2), BLK)
    tail(m, c, 'tuft', '#f5f5f5')
    return m


def mk_chicken():
    m = Model('Chicken')
    m.ball((0, 2.6, 0), (3.0, 3.0, 3.4), '#ffffff')
    m.ball((0, 4.6, 1.0), (1.9, 1.9, 1.9), '#ffffff')
    m.box((0, 5.7, 1.0), (0.4, 0.7, 1.0), '#e53935')
    m.box((0, 5.5, 1.5), (0.4, 0.5, 0.7), '#e53935')
    m.box((0, 4.35, 2.25), (0.8, 0.45, 0.9), '#ffb21c')
    m.box((0, 3.8, 2.0), (0.4, 0.7, 0.35), '#e53935')
    for s in (-1, 1):
        m.ball((s * 0.55, 4.8, 1.85), 0.35, BLK)
        m.ball((s * 1.55, 2.7, 0), (0.5, 1.8, 2.2), '#f1ece4', rot=(-10, 0, s * 8))
        m.box((s * 0.6, 0.8, 0.2), (0.3, 1.6, 0.3), '#ffb21c')
        m.box((s * 0.6, 0.12, 0.45), (0.9, 0.25, 1.2), '#ffb21c')
    for i, a in enumerate((-20, 0, 20)):
        m.ball((0, 3.3 + (1 if i == 1 else 0) * 0.3, -2.0), (0.5, 2.0, 0.8), '#e9e3d8', rot=(35, a, 0))
    return m


def mk_duck():
    m = Model('Duck')
    m.ball((0, 1.9, 0), (3.2, 2.6, 4.2), '#ffd23c')
    m.ball((0, 4.0, 1.3), (2.2, 2.2, 2.2), '#ffd23c')
    m.box((0, 3.7, 2.55), (1.5, 0.45, 1.2), '#ff8f1c')
    for s in (-1, 1):
        m.ball((s * 0.65, 4.3, 2.25), 0.35, BLK)
        m.ball((s * 1.7, 2.2, -0.1), (0.5, 1.6, 2.4), '#f0b81e', rot=(-10, 0, s * 8))
        m.box((s * 0.8, 0.12, 0.8), (1.0, 0.25, 1.3), '#ff8f1c')
        m.box((s * 0.8, 0.45, 0.5), (0.3, 0.6, 0.3), '#ff8f1c')
    m.ball((0, 2.9, -2.3), (1.4, 1.2, 1.0), '#ffd23c', rot=(30, 0, 0))
    return m


def mk_sheep():
    m = Model('Sheep')
    c = quad(m, '#fafafa', body=(3.2, 2.8, 4.2), leg=(1.5, 0.8), head=(1.8, 1.9, 1.8), hup=-0.3, hfwd=0.4,
             legcol='#3a3a3a', headcol='#3a3a3a', ears='none', snout=None, mat='Fabric', eyes=False, round_body=True)
    pts = [(0, c['by'] + 1.4, 0), (-1.0, c['by'] + 1.2, 1.2), (1.0, c['by'] + 1.2, -1.2), (-1.0, c['by'] + 1.2, -1.3),
           (1.0, c['by'] + 1.2, 1.3), (1.7, c['by'] + 0.2, 0.2), (-1.7, c['by'] + 0.2, -0.3), (0, c['by'] + 0.1, 2.2),
           (0, c['by'] + 0.1, -2.2), (1.6, c['by'] - 0.5, 1.4), (-1.6, c['by'] - 0.5, -1.4)]
    for p in pts:
        m.ball(p, 1.6, '#ffffff', 'Fabric')
    m.ball((0, c['hy'] + 1.2, c['hz'] - 0.2), 1.4, '#ffffff', 'Fabric')
    for s in (-1, 1):
        m.ball((s * 0.45, c['hy'] + 0.15, c['fz'] - 0.02), 0.38, '#ffffff')
        m.ball((s * 0.45, c['hy'] + 0.15, c['fz'] + 0.12), 0.18, BLK)
        m.box((s * 1.2, c['hy'] + 0.1, c['hz'] - 0.2), (0.9, 0.4, 0.5), '#3a3a3a', rot=(0, 0, s * -20))
    return m


def mk_frog():
    m = Model('Frog')
    m.ball((0, 1.7, 0), (3.6, 3.0, 4.0), '#6fd250')
    m.ball((0, 1.4, 0.4), (2.8, 2.2, 3.6), '#c5f2a8')
    for s in (-1, 1):
        m.ball((s * 1.05, 3.5, 1.1), 1.4, '#6fd250')
        m.ball((s * 1.05, 3.6, 1.65), 0.9, '#ffffff')
        m.ball((s * 1.05, 3.6, 2.05), 0.5, BLK)
        m.ball((s * 1.9, 0.9, -0.9), (1.2, 1.8, 2.8), '#5bb83f')
        m.box((s * 1.7, 0.2, 1.7), (1.4, 0.4, 1.2), '#5bb83f')
        m.box((s * 1.5, 0.2, -2.0), (1.4, 0.4, 1.2), '#5bb83f')
    m.box((0, 1.5, 2.05), (2.0, 0.12, 0.2), '#2a6b1e')
    return m


def mk_penguin():
    m = Model('Penguin')
    m.ball((0, 3.0, 0), (3.6, 5.2, 3.2), '#22262d')
    m.ball((0, 2.8, 0.45), (2.6, 4.4, 2.8), '#f3f9ff')
    m.ball((0, 5.4, 0.2), (2.6, 2.4, 2.4), '#22262d')
    m.box((0, 5.1, 1.7), (1.0, 0.45, 1.0), '#ff9d1c')
    for s in (-1, 1):
        m.ball((s * 0.6, 5.7, 1.35), 0.4, '#ffffff')
        m.ball((s * 0.6, 5.7, 1.55), 0.22, BLK)
        m.ball((s * 2.0, 3.3, 0.1), (0.5, 2.8, 1.5), '#22262d', rot=(0, 0, s * 12))
        m.box((s * 0.9, 0.2, 0.9), (1.2, 0.4, 1.9), '#ff9d1c')
    return m


def mk_lion():
    m = Model('Lion')
    c = quad(m, '#e8b04e', body=(2.8, 2.6, 4.6), leg=(1.7, 0.9), head=(2.2, 2.0, 1.9), ears='round', earcol='#c9893a',
             snout=(1.2, 0.8, 0.6), snoutcol='#fff0cc', nose='#7a3a22', hup=0.2, hfwd=0.3, hoof='#c9893a')
    for i in range(10):
        a = math.radians(i * 36)
        m.ball((c['hw'] * 0.95 * math.sin(a), c['hy'] + c['hh'] * 0.9 * math.cos(a), c['hz'] - 0.55), (1.5, 1.5, 1.6),
               '#9a5a1f', 'Fabric')
    m.ball((0, c['hy'], c['hz'] - 0.6), (3.0, 3.0, 1.2), '#9a5a1f', 'Fabric')
    # redraw face over the mane
    m.box((0, c['hy'], c['hz'] - 0.1), (2.2, 2.0, 1.9), '#e8b04e')
    m.box((0, c['hy'] - 0.4, c['fz'] + 0.1), (1.2, 0.8, 0.6), '#fff0cc')
    m.box((0, c['hy'] - 0.1, c['fz'] + 0.35), (0.5, 0.3, 0.2), '#7a3a22')
    for s in (-1, 1):
        m.ball((s * 0.6, c['hy'] + 0.25, c['fz'] - 0.02), 0.4, BLK)
    tail(m, c, 'tuft', '#e8b04e')
    return m


def mk_monkey():
    m = Model('Monkey')
    c = quad(m, '#7b4a2d', body=(2.4, 2.8, 3.8), leg=(2.0, 0.8), head=(2.2, 2.0, 1.9), ears='none', snout=(1.5, 1.1, 0.5),
             snoutcol='#e2b98c', nose='#4a2a18', round_body=True)
    m.box((0, c['hy'] + 0.1, c['fz'] - 0.05), (1.9, 1.3, 0.1), '#e2b98c')
    for s in (-1, 1):
        m.ball((s * 1.35, c['hy'], c['hz'] - 0.3), 1.2, '#7b4a2d')
        m.ball((s * 1.35, c['hy'], c['hz'] - 0.05), 0.7, '#e2b98c')
    m.box((0, 3.0, -2.5), (0.45, 0.45, 2.6), '#7b4a2d', rot=(-30, 0, 0))
    m.box((0, 4.6, -3.6), (0.45, 2.2, 0.45), '#7b4a2d', rot=(-15, 0, 0))
    m.box((0, 5.6, -3.4), (0.45, 0.45, 1.4), '#7b4a2d', rot=(30, 0, 0))
    return m


def mk_elephant():
    m = Model('Elephant')
    c = quad(m, '#9aa3ad', body=(3.8, 3.6, 5.2), leg=(1.9, 1.3), head=(2.8, 2.8, 2.4), ears='none', snout=None,
             mat='Slate', hup=-0.2, hfwd=0.3, eyes=False, hoof='#c9ced4')
    for s in (-1, 1):
        m.box((s * (c['hw'] / 2 + 0.7), c['hy'] + 0.2, c['hz'] - 0.2), (0.4, 3.2, 3.0), '#8a939d', 'Slate')
        m.ball((s * 0.9, c['hy'] + 0.4, c['fz'] - 0.02), 0.45, BLK)
        m.box((s * 0.9, c['hy'] - 1.2, c['fz'] + 0.2), (0.3, 0.3, 1.5), '#fff8e8', rot=(-20, 0, 0))
    for i, (y, z) in enumerate([(-0.5, 0.0), (-1.4, 0.3), (-2.3, 0.7), (-2.9, 1.2)]):
        m.box((0, c['hy'] + y, c['fz'] + z), (1.0, 1.1, 1.0), '#9aa3ad', 'Slate')
    m.box((0, c['top'] - 0.3, -c['l'] / 2 - 0.3), (0.35, 1.8, 0.35), '#8a939d')
    return m


def mk_giraffe():
    m = Model('Giraffe')
    c = quad(m, '#f5cf5e', body=(2.6, 2.6, 4.0), leg=(2.8, 0.8), head=(1.7, 1.6, 2.4), ears='point', neck=3.8,
             snout=(1.1, 0.8, 0.4), snoutcol='#fbe7a8', nose='#7a4a22', hup=0.0, hfwd=0.6, hoof='#5b3317')
    for p, sz in [((0.6, c['top'] + 0.03, 0.6), (1.0, 1.0)), ((-0.7, c['top'] + 0.03, -0.9), (1.2, 0.9))]:
        m.box(p, (sz[0], 0.08, sz[1]), '#9b5a2a')
    for y in (c['top'] + 1.0, c['top'] + 2.4):
        m.box((0, y, c['l'] / 2 - 0.4 + 0.45), (0.5, 0.7, 0.1), '#9b5a2a')
    m.box((1.31, 3.0, 0.5), (0.08, 1.2, 1.2), '#9b5a2a')
    m.box((-1.31, 3.0, -0.8), (0.08, 1.0, 1.4), '#9b5a2a')
    for s in (-1, 1):
        m.cyl((s * 0.4, c['ey'] + 0.5, c['hz'] - 0.3), (0.3, 1.0, 0.3), '#9b5a2a')
        m.ball((s * 0.4, c['ey'] + 1.05, c['hz'] - 0.3), 0.5, '#5b3317')
    tail(m, c, 'tuft', '#f5cf5e')
    return m


def mk_zebra():
    m = Model('Zebra')
    c = quad(m, '#fafafa', body=(2.8, 2.6, 4.6), leg=(2.0, 0.8), head=(2.0, 2.0, 2.6), ears='point', earcol='#161616',
             snout=(1.5, 1.0, 0.5), snoutcol='#2a2a2a', nose='#000000', hup=0.4, hfwd=0.3, neck=0.6, hoof='#161616')
    for z in (-1.8, -0.9, 0, 0.9, 1.8):
        m.box((0, c['by'], z), (c['w'] + 0.06, c['h'] + 0.06, 0.3), '#161616')
    for z in (-1.3, -0.4, 0.4):
        m.box((0, c['hy'] - 0.6 + 0.0, c['hz'] + z - 0.2), (c['hw'] + 0.06, 0.28, 0.25), '#161616')
    for i in range(6):
        m.box((0, c['top'] + 0.5 + i * 0.12, c['l'] / 2 - 0.1 - i * 0.2 + 0.3), (0.3, 0.8, 0.3), '#161616')
    tail(m, c, 'tuft', '#fafafa')
    return m


def mk_tiger():
    m = Model('Tiger')
    c = quad(m, '#f08a2a', body=(2.8, 2.5, 4.8), leg=(1.6, 0.9), head=(2.5, 2.1, 2.0), ears='round', earcol='#f08a2a',
             snout=(1.3, 0.8, 0.6), snoutcol='#fff2e0', nose='#ff7aa8', hoof='#fff2e0')
    for z in (-1.8, -0.9, 0, 0.9, 1.8):
        m.box((0, c['top'] + 0.02, z), (c['w'] + 0.06, 0.1, 0.25), '#1b1b1b')
        m.box((c['w'] / 2 + 0.02, c['by'] + 0.3, z), (0.1, 1.1, 0.25), '#1b1b1b')
        m.box((-c['w'] / 2 - 0.02, c['by'] + 0.3, z), (0.1, 1.1, 0.25), '#1b1b1b')
    for s in (-1, 1):
        for dy in (0.6, 0.0):
            m.box((s * 0.85, c['hy'] + 0.55 + dy * 0.5 - 0.2, c['fz'] + 0.0), (0.4, 0.15, 0.1), '#1b1b1b')
    tail(m, c, 'long', '#f08a2a')
    m.box((0, c['top'] - 0.1, -c['l'] / 2 - 2.2), (0.5, 0.5, 0.5), '#1b1b1b')
    return m


def mk_wolf():
    m = Model('Wolf')
    c = quad(m, '#6b7686', body=(2.6, 2.4, 4.8), leg=(2.0, 0.8), head=(2.2, 2.0, 2.0), ears='point', earcol='#4d5666',
             snout=(1.1, 0.9, 1.4), snoutcol='#c3cad4', nose='#111111', hoof='#4d5666')
    m.box((0, c['top'] + 0.02, 0.3), (c['w'] + 0.05, 0.12, 2.0), '#4d5666')
    m.box((0, c['hy'] + 0.3, c['hz'] - 0.2), (0.5, 0.6, 1.2), '#4d5666')
    tail(m, c, 'bushy', '#6b7686')
    return m


def mk_koala():
    m = Model('Koala')
    c = quad(m, '#aab2bd', body=(3.0, 3.0, 3.6), leg=(1.4, 0.9), head=(2.6, 2.3, 2.0), ears='none', snout=None,
             mat='Fabric', round_body=True, round_head=True)
    for s in (-1, 1):
        m.ball((s * 1.7, c['ey'] - 0.2, c['hz'] - 0.3), (1.7, 1.7, 0.8), '#aab2bd', 'Fabric')
        m.ball((s * 1.7, c['ey'] - 0.2, c['hz'] - 0.05), (1.0, 1.0, 0.5), '#e8e3dc', 'Fabric')
    m.ball((0, c['hy'] - 0.2, c['fz'] + 0.05), (0.9, 1.3, 0.7), '#2a2a30')
    m.ball((0, c['by'] - 0.6, c['l'] / 2 + 0.1), (2.0, 1.6, 0.6), '#e8e3dc', 'Fabric')
    return m


def mk_hippo():
    m = Model('Hippo')
    c = quad(m, '#8d7ba9', body=(3.6, 3.0, 4.8), leg=(1.2, 1.2), head=(3.0, 2.2, 2.6), ears='round', earcol='#8d7ba9',
             snout=(3.0, 1.4, 1.0), snoutcol='#a794c4', nose=None, round_body=True, hup=-0.4, hfwd=0.3)
    for s in (-1, 1):
        m.ball((s * 0.7, c['hy'] - 0.1, c['fz'] + 0.9), 0.4, '#5a4a73')
        m.ball((s * 1.0, c['hy'] + 0.95, c['fz'] - 0.6), 0.9, '#8d7ba9')
        m.ball((s * 1.0, c['hy'] + 1.0, c['fz'] - 0.3), 0.55, '#f2f2f2')
        m.ball((s * 1.0, c['hy'] + 1.0, c['fz'] - 0.1), 0.3, BLK)
    tail(m, c, 'ball', '#8d7ba9')
    return m


def mk_turtle():
    m = Model('Turtle')
    for sx in (-1, 1):
        for sz in (-1, 1):
            m.box((sx * 1.9, 0.6, sz * 1.8), (1.2, 1.2, 1.4), '#6fbf5b')
    m.ball((0, 1.7, 0), (4.8, 3.4, 5.4), '#8a5d34', 'Cobblestone')
    for x, z in [(0, 0), (1.4, 0.9), (-1.4, 0.9), (1.4, -1.0), (-1.4, -1.0), (0, 1.8), (0, -1.8)]:
        m.ball((x, 2.35 - (abs(x) + abs(z)) * 0.18, z), (1.5, 1.0, 1.5), '#4f9a3b', 'Cobblestone')
    m.box((0, 0.7, 0), (4.4, 0.7, 5.0), '#e6d3a1')
    m.ball((0, 1.9, 3.2), (1.9, 1.9, 2.2), '#6fbf5b')
    for s in (-1, 1):
        m.ball((s * 0.5, 2.2, 3.95), 0.35, BLK)
    m.box((0, 0.7, -2.9), (0.7, 0.5, 1.0), '#6fbf5b')
    return m


def mk_shark():
    m = Model('Shark')
    # floating pose on a small wave base
    m.ball((0, 2.4, 0), (3.2, 3.2, 7.0), '#6b97bd')
    m.ball((0, 1.7, 0.4), (2.8, 2.0, 6.4), '#f2f7fb')
    m.box((0, 4.5, -0.3), (0.35, 2.2, 1.7), '#4f7da3', rot=(20, 0, 0))
    m.box((0, 3.1, -4.1), (0.35, 2.6, 1.6), '#4f7da3', rot=(-30, 0, 0))
    m.box((0, 1.3, -3.9), (0.35, 1.6, 1.3), '#4f7da3', rot=(40, 0, 0))
    for s in (-1, 1):
        m.box((s * 1.9, 1.3, 0.8), (0.3, 1.8, 1.1), '#4f7da3', rot=(0, 0, s * 55))
        m.ball((s * 1.15, 3.1, 2.7), 0.5, '#ffffff')
        m.ball((s * 1.15, 3.1, 3.0), 0.28, BLK)
    m.box((0, 1.7, 3.3), (2.2, 0.15, 0.2), '#2b4a63')
    for i in range(5):
        x = -0.9 + i * 0.45
        m.box((x, 1.9, 3.35), (0.3, 0.3, 0.3), '#ffffff', rot=(0, 0, 45))
    m.cyl((0, 0.3, 0), (4.2, 0.6, 4.2), '#4aa8e8', 'Glass', tr=0.35)
    return m


def mk_octopus():
    m = Model('Octopus')
    m.ball((0, 4.0, 0), (4.4, 4.6, 4.2), '#9a58c4')
    for i in range(8):
        a = math.radians(i * 45 + 22)
        for k, (r, y, s) in enumerate([(1.5, 1.5, 1.1), (2.3, 0.8, 0.95), (3.0, 0.4, 0.8)]):
            m.ball((r * math.sin(a), y, r * math.cos(a)), (s, s * 0.9, s), '#7e3fa6')
    for s in (-1, 1):
        m.ball((s * 1.0, 3.7, 1.8), 1.0, '#ffffff')
        m.ball((s * 1.0, 3.7, 2.25), 0.5, BLK)
    for p in [(-1.5, 5.4, 0.5), (1.2, 5.8, 0.2), (0.2, 6.0, 0.9), (-0.6, 5.0, 1.7), (1.8, 5.0, 1.2)]:
        m.ball(p, 0.45, '#f0b4e0')
    m.box((0, 2.8, 2.0), (0.8, 0.12, 0.2), '#5a2a7a')
    return m


def mk_unicorn():
    m = Model('Unicorn')
    cols = ['#ff8f8f', '#ffc98f', '#fff08f', '#a9f5a1', '#8fd0ff', '#c7a4ff']
    c = quad(m, '#ffffff', body=(2.6, 2.6, 4.6), leg=(2.2, 0.8), head=(2.0, 2.0, 2.6), ears='point', earcol='#ffffff',
             snout=(1.3, 0.9, 0.4), snoutcol='#ffe0ee', nose='#ff7aa8', hup=0.4, hfwd=0.3, neck=0.6, hoof='#ffd1f0')
    for i in range(4):
        m.cyl((0, c['ey'] + 0.6 + i * 0.5, c['hz'] + 0.5), (0.7 - i * 0.14, 0.55, 0.7 - i * 0.14),
              '#ffe58a' if i % 2 else '#fff4c2', 'Neon')
    for i, col in enumerate(cols):
        m.box((0, c['top'] + 0.6 - i * 0.05, c['l'] / 2 - 0.2 - i * 0.2 + 0.6), (0.5, 1.0, 0.5), col)
        m.box((0, c['top'] - 0.4 - i * 0.2, -c['l'] / 2 - 0.4 - i * 0.05), (0.5, 0.9, 0.5), col)
    return m


def mk_dragon():
    m = Model('Dragon')
    c = quad(m, '#b3261e', body=(2.8, 2.6, 4.8), leg=(1.6, 1.0), head=(2.2, 2.0, 2.4), ears='none',
             snout=(1.2, 0.9, 1.0), snoutcol='#d94a3a', nose='#2a0c0a', hoof='#2a0c0a', hup=0.3, hfwd=0.4)
    m.box((0, c['by'] - 0.5, c['l'] / 2 + 0.03), (2.0, 1.4, 0.1), '#ffcf5c')
    for s in (-1, 1):
        m.box((s * 0.7, c['ey'] + 0.7, c['hz'] - 0.4), (0.35, 1.5, 0.35), '#f1e4c8', rot=(-25, 0, s * -10))
        m.box((s * 3.2, c['top'] + 1.1, 0.0), (3.6, 0.15, 3.0), '#7a1510', rot=(0, 0, s * 25))
        m.box((s * 4.8, c['top'] + 2.0, 0.0), (0.2, 1.2, 0.2), '#2a0c0a', rot=(0, 0, s * 25))
        m.ball((s * 0.6, c['hy'] + 0.3, c['fz'] - 0.02), 0.4, '#ffd23c', 'Neon')
        m.ball((s * 0.6, c['hy'] + 0.3, c['fz'] + 0.1), 0.18, BLK)
    for i in range(5):
        m.box((0, c['top'] + 0.2, 1.8 - i * 1.0), (0.3, 0.8, 0.5), '#2a0c0a', rot=(0, 0, 45))
    m.box((0, c['top'] - 0.6, -c['l'] / 2 - 1.0), (0.9, 0.9, 2.4), '#b3261e', rot=(-20, 0, 0))
    m.box((0, c['top'] - 1.2, -c['l'] / 2 - 2.5), (0.6, 0.6, 1.8), '#b3261e', rot=(-35, 0, 0))
    m.box((0, c['top'] - 1.9, -c['l'] / 2 - 3.4), (0.5, 0.9, 0.5), '#ff9a1f', 'Neon', rot=(0, 0, 45))
    return m


def mk_raccoon():
    m = Model('Raccoon')
    c = quad(m, '#8f9aa4', body=(2.6, 2.4, 4.0), leg=(1.5, 0.8), head=(2.4, 2.0, 2.0), ears='round', earcol='#8f9aa4',
             snout=(1.1, 0.8, 0.9), snoutcol='#f1f1f1', nose='#111111', hoof='#2a2f34')
    m.box((0, c['hy'] + 0.2, c['fz'] + 0.02), (c['hw'] + 0.05, 0.7, 0.1), '#1e2226')
    for s in (-1, 1):
        m.ball((s * 0.6, c['hy'] + 0.2, c['fz'] - 0.02), 0.4, '#ffffff')
        m.ball((s * 0.6, c['hy'] + 0.2, c['fz'] + 0.1), 0.2, BLK)
    m.ball((0, c['top'] - 0.5, -c['l'] / 2 - 1.5), (1.5, 1.5, 3.4), '#8f9aa4', rot=(-15, 0, 0))
    for z in (-1.0, -2.0, -3.0):
        m.box((0, c['top'] - 0.55 + (z + 1) * 0.1, -c['l'] / 2 + z - 0.3), (1.52, 1.52, 0.4), '#1e2226', rot=(-15, 0, 0))
    return m


def mk_owl():
    m = Model('Owl')
    m.ball((0, 3.0, 0), (3.8, 5.0, 3.4), '#9b6f45')
    m.ball((0, 2.6, 0.5), (2.6, 3.6, 2.6), '#e5c89a')
    m.ball((0, 5.0, 0.2), (3.4, 2.6, 2.8), '#9b6f45')
    for s in (-1, 1):
        m.ball((s * 0.95, 5.2, 1.4), 1.7, '#fff3c4')
        m.ball((s * 0.95, 5.2, 2.0), 0.9, '#ffb21c')
        m.ball((s * 0.95, 5.2, 2.3), 0.5, BLK)
        m.box((s * 1.35, 6.7, 0.1), (0.7, 1.2, 0.5), '#6d4a2b', rot=(0, 0, s * -15))
        m.ball((s * 2.0, 3.0, 0.0), (0.6, 3.4, 2.2), '#6d4a2b', rot=(0, 0, s * 8))
        m.box((s * 0.7, 0.25, 0.9), (1.0, 0.5, 1.4), '#ff9d1c')
    m.box((0, 4.5, 2.2), (0.6, 0.8, 0.5), '#ff9d1c', rot=(0, 0, 45))
    for k in range(3):
        m.box((0, 2.2 - k * 0.7, 1.9 - k * 0.1), (0.9, 0.2, 0.2), '#c9a36e')
    return m


def mk_deer():
    m = Model('Deer')
    c = quad(m, '#b57d49', body=(2.4, 2.4, 4.4), leg=(2.6, 0.7), head=(2.0, 1.9, 2.2), ears='point', earcol='#b57d49',
             snout=(1.0, 0.8, 0.8), snoutcol='#e8d2b0', nose='#111111', neck=1.4, hup=0.0, hoof='#3a2a1c')
    for x, z in [(-0.7, 0.6), (0.6, -0.4), (0.2, 1.4), (-0.4, -1.4), (0.8, 1.2), (-0.8, -0.2)]:
        m.ball((x, c['top'] - 0.02, z), (0.4, 0.15, 0.4), '#fff1da')
    for s in (-1, 1):
        m.box((s * 0.6, c['ey'] + 1.0, c['hz'] - 0.4), (0.25, 2.2, 0.25), '#d8c29a', rot=(0, 0, s * -15))
        m.box((s * 1.0, c['ey'] + 1.5, c['hz'] - 0.4), (0.22, 1.2, 0.22), '#d8c29a', rot=(0, 0, s * -55))
        m.box((s * 0.5, c['ey'] + 1.6, c['hz'] - 0.4), (0.22, 1.0, 0.22), '#d8c29a', rot=(0, 0, s * 25))
    m.ball((0, c['top'] - 0.4, -c['l'] / 2 - 0.3), (0.8, 1.2, 0.8), '#ffffff')
    return m


def mk_fox():
    m = Model('Fox')
    c = quad(m, '#ea7a2c', body=(2.4, 2.2, 4.2), leg=(1.7, 0.7), head=(2.3, 1.9, 2.0), ears='point', earcol='#ea7a2c',
             snout=(1.0, 0.7, 1.3), snoutcol='#fff2e0', nose='#111111', hoof='#2a1a12')
    m.box((0, c['hy'] - 0.7, c['fz'] - 0.2), (1.9, 0.6, 1.5), '#fff2e0')
    for s in (-1, 1):
        m.box((s * c['hw'] * 0.33, c['ey'] + 0.9, c['hz'] - 0.2), (0.5, 0.45, 0.42), '#2a1a12', rot=(0, 0, s * -12))
    m.box((0, c['by'] - 0.4, c['l'] / 2 + 0.03), (1.6, 1.3, 0.1), '#fff2e0')
    m.ball((0, c['top'] - 0.4, -c['l'] / 2 - 1.4), (1.8, 1.8, 3.2), '#ea7a2c', rot=(-15, 0, 0))
    m.ball((0, c['top'] - 1.0, -c['l'] / 2 - 2.9), (1.5, 1.5, 1.5), '#fff2e0', rot=(-15, 0, 0))
    return m


def mk_bear():
    m = Model('Bear')
    c = quad(m, '#8b5a32', body=(3.0, 2.8, 4.2), leg=(1.5, 1.1), head=(2.6, 2.3, 2.1), ears='round', earcol='#6b4224',
             snout=(1.4, 1.0, 0.8), snoutcol='#d9b184', nose='#1a1a1a', round_body=True, mat='Wood')
    tail(m, c, 'ball', '#6b4224')
    return m


def mk_panda():
    m = Model('Panda')
    c = quad(m, '#f7f7f7', body=(3.0, 2.8, 4.0), leg=(1.5, 1.1), head=(2.7, 2.3, 2.1), ears='round', earcol='#151515',
             legcol='#151515', snout=(1.2, 0.8, 0.6), snoutcol='#f7f7f7', nose='#151515', round_body=True)
    m.box((0, c['by'] + 0.3, 1.4), (c['w'] + 0.1, 1.6, 0.9), '#151515')
    for s in (-1, 1):
        m.ball((s * c['hw'] * 0.27, c['hy'] + c['hh'] * 0.13, c['fz'] - 0.1), (0.95, 1.3, 0.4), '#151515',
               rot=(0, 0, s * 25))
        m.ball((s * c['hw'] * 0.27, c['hy'] + c['hh'] * 0.13, c['fz'] + 0.0), 0.3, '#ffffff')
        m.ball((s * c['hw'] * 0.27, c['hy'] + c['hh'] * 0.13, c['fz'] + 0.12), 0.18, BLK)
    tail(m, c, 'ball', '#f7f7f7')
    return m


ANIMALS = [mk_chicken, mk_duck, mk_pig, mk_cow, mk_sheep, mk_bunny, mk_cat, mk_dog, mk_frog, mk_fox, mk_bear,
           mk_panda, mk_raccoon, mk_koala, mk_owl, mk_penguin, mk_turtle, mk_monkey, mk_zebra, mk_tiger, mk_lion,
           mk_giraffe, mk_elephant, mk_hippo, mk_wolf, mk_deer, mk_shark, mk_octopus, mk_unicorn, mk_dragon]

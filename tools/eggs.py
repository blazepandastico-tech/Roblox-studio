"""30 stylised eggs (Roblox simple style), each one hatching one of the 30 animals."""
import math

from core import Model, dark, light, mix

A, B = 2.0, 2.6  # egg half-width (x/z) and half-height (y); centre sits at y = B


def sp(th, ph):
    """Point on the egg surface. th = azimuth (0 = front +Z), ph = elevation (deg)."""
    t, p = math.radians(th), math.radians(ph)
    return (A * math.cos(p) * math.sin(t), B + B * math.sin(p), A * math.cos(p) * math.cos(t))


def base(m, col, mat='SmoothPlastic', tr=0):
    m.ball((0, B, 0), (2 * A, 2 * B, 2 * A), col, mat, tr=tr)


def spot(m, th, ph, r, col, mat='SmoothPlastic', sq=1.0):
    m.ball(sp(th, ph), (2 * r, 2 * r * sq, 2 * r), col, mat)


def ring(m, ph, n, r, col, off=0, mat='SmoothPlastic'):
    for i in range(n):
        spot(m, off + 360 * i / n, ph, r, col, mat)


def band(m, ph, thick, col, mat='SmoothPlastic', grow=0.05):
    yy = B * math.sin(math.radians(ph))
    rad = A * math.sqrt(max(0.0, 1 - (yy / B) ** 2)) + grow
    m.cyl((0, B + yy, 0), (2 * rad, thick, 2 * rad), col, mat)


def eyes_on_top(m, col='#ffffff', pup='#111111'):
    for s in (-1, 1):
        m.ball((s * 0.95, 4.85, 0.3), 1.2, col)
        m.ball((s * 0.95, 4.9, 0.85), 0.55, pup)


def ear(m, x, y, z, col, rz=0, size=(0.9, 1.1, 0.4), mat='SmoothPlastic'):
    m.box((x, y, z), size, col, mat, rot=(0, 0, rz))


def sparkle(m, x, y, z, col, s=0.45):
    m.box((x, y, z), (s, s, s), col, 'Neon', rot=(45, 45, 0))


def egg_chicken(m):
    base(m, '#f6e7c8')
    for th, ph in [(20, 30), (-30, 10), (60, -10), (-70, -30), (0, -40), (110, 20), (-110, 40), (30, 70), (-10, 50)]:
        spot(m, th, ph, 0.2, '#b07a4a')


def egg_duck(m):
    base(m, '#bfe8f2')
    band(m, 25, 0.3, '#ffffff')
    band(m, -20, 0.3, '#ffffff')
    for th in (-25, 0, 25):
        spot(m, th, -50, 0.28, '#ffb829')
    m.box((0, 4.2, 1.75), (0.9, 0.3, 0.9), '#ff9d1c', rot=(-20, 0, 0))


def egg_pig(m):
    base(m, '#ffa9c6')
    for th, ph in [(-60, 30), (70, 20), (-80, -20), (110, -40), (30, 55)]:
        spot(m, th, ph, 0.55, '#ff86ad')
    m.ball((0, 2.5, 1.85), (1.7, 1.3, 0.8), '#ff86ad')
    for s in (-1, 1):
        m.ball((s * 0.3, 2.5, 2.25), (0.25, 0.4, 0.2), '#7a2a47')
        ear(m, s * 1.2, 4.9, 0.4, '#ff86ad', rz=s * 25)


def egg_cow(m):
    base(m, '#f5f5f5')
    for th, ph, r in [(-50, 20, 0.9), (-60, 30, 0.6), (50, -10, 0.85), (60, -20, 0.55), (150, 20, 0.9), (0, 65, 0.7)]:
        spot(m, th, ph, r, '#1d1d1d')
    for s in (-1, 1):
        m.box((s * 0.9, 5.15, 0.2), (0.4, 0.8, 0.4), '#e8dcc0', rot=(0, 0, s * -15))


def egg_sheep(m):
    base(m, '#fafafa', 'Fabric')
    for ph, n, off in [(60, 5, 10), (35, 7, 0), (10, 8, 20), (-15, 8, 0), (-40, 7, 20), (-65, 5, 0)]:
        ring(m, ph, n, 0.55, '#ffffff', off, 'Fabric')
    m.ball((0, 5.0, 0), 1.3, '#ffffff', 'Fabric')
    for s in (-1, 1):
        ear(m, s * 1.7, 4.0, 0.2, '#3a3a3a', rz=s * 70, size=(1.0, 0.5, 0.5))


def egg_bunny(m):
    base(m, '#e7d8ff')
    for s in (-1, 1):
        m.ball((s * 0.7, 6.1, 0), (0.9, 3.0, 0.5), '#e7d8ff', rot=(0, 0, s * -8))
        m.ball((s * 0.7, 6.1, 0.2), (0.45, 2.3, 0.3), '#ffb7d5', rot=(0, 0, s * -8))
    m.ball((0, 2.9, -1.95), 1.0, '#ffffff')
    spot(m, 0, 5, 0.25, '#ff7aa8')


def egg_cat(m):
    base(m, '#f2a24d')
    for ph in (35, 5, -25, -50):
        for th in (-40, 40):
            m.box(sp(th, ph), (0.9 if ph > 0 else 0.7, 0.2, 0.2), '#c06a1d', rot=(0, th, 0))
    for s in (-1, 1):
        ear(m, s * 1.0, 5.0, 0.2, '#f2a24d', rz=s * 20, size=(0.9, 1.0, 0.4))
        m.box((s * 1.0, 4.95, 0.45), (0.45, 0.6, 0.2), '#ffb7c5', rot=(0, 0, s * 20))
    m.box((0, 3.2, 1.9), (0.4, 0.3, 0.25), '#ff7aa8')


def egg_dog(m):
    base(m, '#d3a56c')
    spot(m, 25, 25, 0.95, '#6b4220')
    spot(m, -15, -20, 0.7, '#6b4220')
    for s in (-1, 1):
        m.box((s * 2.0, 4.3, 0.2), (0.4, 1.7, 1.0), '#6b4220', rot=(0, 0, s * -12))
    m.ball((0, 3.0, 1.9), (1.0, 0.8, 0.6), '#2b1b10')


def egg_frog(m):
    base(m, '#6fd250', 'SmoothPlastic')
    for th, ph in [(-40, 10), (50, 25), (0, -20), (120, 0), (-100, -30), (70, -45), (-70, 45)]:
        spot(m, th, ph, 0.55, '#a6ec7c')
    eyes_on_top(m)


def egg_fox(m):
    base(m, '#ea7a2c')
    m.ball((0, 1.0, 0.15), (3.7, 2.0, 3.6), '#fff2e0')  # white belly
    for s in (-1, 1):
        ear(m, s * 1.1, 5.1, 0.1, '#ea7a2c', rz=s * 15, size=(0.9, 1.3, 0.4))
        m.box((s * 1.1, 5.6, 0.1), (0.5, 0.6, 0.42), '#2a1a12', rot=(0, 0, s * 15))
    m.ball((0, 3.0, 1.9), (1.0, 0.8, 0.6), '#fff2e0')


def egg_bear(m):
    base(m, '#8b5a32', 'Wood')
    for s in (-1, 1):
        m.ball((s * 1.4, 4.9, 0), 1.1, '#6b4224', 'Wood')
        m.ball((s * 1.4, 4.9, 0.3), 0.55, '#c99a6b')
    m.ball((0, 2.4, 1.8), (1.9, 1.7, 0.9), '#d9b184')
    m.ball((0, 2.8, 2.25), (0.5, 0.35, 0.3), '#222222')


def egg_panda(m):
    base(m, '#f7f7f7')
    for s in (-1, 1):
        m.ball((s * 1.45, 4.9, 0), 1.1, '#151515')
        m.ball(sp(s * 35, 18), (1.0, 1.4, 0.8), '#151515', rot=(0, 0, s * 30))
    band(m, -35, 0.6, '#151515', grow=0.0)
    m.ball((0, 2.7, 1.95), (0.6, 0.45, 0.4), '#151515')


def egg_raccoon(m):
    base(m, '#8f9aa4')
    band(m, 28, 0.5, '#1e2226', grow=0.0)
    for s in (-1, 1):
        m.ball(sp(s * 28, 28), (0.7, 0.55, 0.5), '#ffffff')
        ear(m, s * 1.2, 5.0, 0.1, '#8f9aa4', rz=s * 20)
    for ph in (-20, -35, -50):
        band(m, ph, 0.28, '#3a4249')
    m.ball((0, 3.0, 1.95), (0.5, 0.4, 0.35), '#111111')


def egg_koala(m):
    base(m, '#aab2bd', 'Fabric')
    for s in (-1, 1):
        m.ball((s * 1.9, 4.5, 0), (1.6, 1.6, 0.7), '#aab2bd', 'Fabric')
        m.ball((s * 1.9, 4.5, 0.3), (1.0, 1.0, 0.4), '#e8e3dc', 'Fabric')
    m.ball((0, 3.1, 1.95), (0.9, 1.3, 0.7), '#2a2a30')
    m.box((0, 5.35, 0), (0.9, 0.12, 1.5), '#4cbb55', rot=(0, 20, 40))
    m.box((0.3, 5.45, 0.3), (0.9, 0.12, 1.5), '#6fd05a', rot=(0, -35, -30))


def egg_owl(m):
    base(m, '#9b6f45', 'Wood')
    for ph, n, off in [(-5, 6, 0), (-25, 6, 30), (-45, 5, 0), (-60, 4, 40)]:
        ring(m, ph, n, 0.45, '#e5c89a', off)
    for s in (-1, 1):
        m.ball((s * 0.85, 3.9, 1.55), 1.3, '#fff3c4')
        m.ball((s * 0.85, 3.9, 2.05), 0.6, '#111111')
        ear(m, s * 1.2, 5.2, 0.2, '#6d4a2b', rz=s * 18, size=(0.6, 1.1, 0.5))
    m.box((0, 3.4, 2.0), (0.45, 0.6, 0.3), '#ff9d1c', rot=(0, 0, 45))


def egg_penguin(m):
    base(m, '#22262d')
    m.ball((0, 2.4, 0.5), (2.8, 3.8, 3.2), '#f3f9ff', 'Ice')
    m.box((0, 3.3, 1.9), (0.7, 0.35, 0.5), '#ff9d1c')
    for s in (-1, 1):
        m.ball((s * 0.7, 4.0, 1.55), 0.4, '#111111')
        m.box((s * 0.8, 0.25, 1.6), (0.9, 0.3, 1.0), '#ff9d1c')
    sparkle(m, 0, 6.2, 0, '#bfe9ff', 0.4)


def egg_turtle(m):
    base(m, '#3f8f4c', 'Cobblestone')
    for th, ph in [(0, 10), (50, 40), (-50, 40), (90, 0), (-90, 0), (45, -30), (-45, -30), (0, -50), (0, 60)]:
        spot(m, th, ph, 0.7, '#245f31', 'Cobblestone')
    band(m, -62, 0.5, '#d9c48a')
    m.ball((0, 4.9, 0), (1.5, 1.4, 1.5), '#6fbf5b')


def egg_monkey(m):
    base(m, '#7b4a2d')
    m.ball((0, 3.4, 1.4), (2.4, 2.0, 1.6), '#e2b98c')
    for s in (-1, 1):
        m.ball((s * 2.0, 4.4, 0), 1.2, '#7b4a2d')
        m.ball((s * 2.0, 4.4, 0.3), 0.7, '#e2b98c')
        m.ball((s * 0.55, 3.6, 2.0), 0.3, '#111111')
    m.box((0.4, 5.4, 0.2), (0.5, 1.8, 0.5), '#ffe033', rot=(0, 0, -50))
    m.box((-0.2, 5.9, 0.2), (0.5, 1.6, 0.5), '#ffe033', rot=(0, 0, 30))


def egg_zebra(m):
    base(m, '#fafafa')
    for ph in range(-60, 70, 22):
        band(m, ph, 0.38, '#161616')
    for i in range(5):
        m.box((0, 5.1 - i * 0.05, -0.8 + i * 0.4), (0.3, 0.7, 0.3), '#161616')
    sparkle(m, -2.8, 3.0, 0, '#ffffff', 0.3)


def egg_tiger(m):
    base(m, '#f08a2a')
    for th in range(0, 360, 36):
        for ph in (40, 5, -35):
            m.box(sp(th, ph), (0.18, 1.1, 0.25), '#1b1b1b', rot=(0, th, 0))
    for s in (-1, 1):
        ear(m, s * 1.1, 5.0, 0.1, '#f08a2a', rz=s * 20)
    m.ball((0, 2.9, 1.9), (1.1, 0.8, 0.6), '#fff2e0')


def egg_lion(m):
    base(m, '#eab84a', 'Foil')
    for th in range(0, 360, 30):
        for ph, r in ((15, 0.75), (-20, 0.8)):
            m.ball(sp(th, ph), r * 2, '#a8601f', 'Fabric')
    for ph, off in ((55, 15), (-50, 15)):
        ring(m, ph, 6, 0.7, '#a8601f', off, 'Fabric')
    m.ball((0, 2.9, 1.9), (1.2, 0.9, 0.6), '#fff0cc')
    for s in (-1, 1):
        m.ball((s * 0.6, 3.5, 1.95), 0.3, '#111111')


def egg_giraffe(m):
    base(m, '#f5cf5e')
    for th, ph, r in [(-40, 30, 0.8), (40, 40, 0.7), (0, -10, 0.9), (80, -20, 0.75), (-85, 0, 0.8),
                      (130, 25, 0.8), (-130, -25, 0.7), (30, -50, 0.65), (-40, -45, 0.7)]:
        spot(m, th, ph, r, '#9b5a2a')
    for s in (-1, 1):
        m.cyl((s * 0.8, 5.5, 0), (0.35, 1.2, 0.35), '#9b5a2a')
        m.ball((s * 0.8, 6.2, 0), 0.6, '#5b3317')


def egg_elephant(m):
    base(m, '#9aa3ad', 'Slate')
    for s in (-1, 1):
        m.ball((s * 2.1, 3.7, 0.3), (0.5, 3.0, 2.6), '#8a939d', 'Slate')
        m.box((s * 0.9, 2.1, 1.9), (0.3, 1.5, 0.3), '#fff8e8', rot=(-30, 0, s * 10))
    for i, y in enumerate((3.0, 2.4, 1.8)):
        m.ball((0, y, 1.9 + i * 0.1), (0.9, 0.7, 0.7), '#8a939d', 'Slate')
    m.ball((0, 3.8, 1.8), (1.0, 0.4, 0.4), '#8a939d', 'Slate')


def egg_hippo(m):
    base(m, '#8d7ba9')
    m.ball((0, 2.7, 1.5), (2.8, 1.8, 1.6), '#a794c4')
    for s in (-1, 1):
        m.ball((s * 0.55, 3.3, 2.1), 0.4, '#5a4a73')
        m.ball((s * 1.4, 4.7, 0.2), 0.8, '#8d7ba9')
        spot(m, s * 35, 40, 0.35, '#111111')


def egg_wolf(m):
    base(m, '#5b6574', 'Slate')
    for th, ph in [(-70, 20), (70, 10), (-90, -20), (95, -30)]:
        m.box(sp(th, ph), (0.18, 1.1, 0.2), '#aab6c6', rot=(0, th, 25))
    m.ball((0, 3.5, 1.9), 1.2, '#f4ecb0', 'Neon')   # moon
    m.ball((0.3, 3.6, 2.15), 1.1, '#5b6574')
    for s in (-1, 1):
        ear(m, s * 1.1, 5.1, 0.1, '#47505e', rz=s * 18, size=(0.8, 1.4, 0.4))


def egg_deer(m):
    base(m, '#b57d49')
    for th, ph, r in [(-40, 30, 0.3), (30, 35, 0.3), (0, 10, 0.3), (60, -10, 0.3), (-65, -5, 0.3),
                      (20, -30, 0.3), (-30, -40, 0.3), (100, 20, 0.3), (-100, 30, 0.3)]:
        spot(m, th, ph, r, '#fff1da')
    for s in (-1, 1):
        m.box((s * 0.9, 5.7, 0), (0.25, 1.9, 0.25), '#d8c29a', rot=(0, 0, s * -20))
        m.box((s * 1.4, 6.0, 0), (0.22, 1.0, 0.22), '#d8c29a', rot=(0, 0, s * -55))
        m.box((s * 0.7, 6.3, 0), (0.22, 0.8, 0.22), '#d8c29a', rot=(0, 0, s * 20))


def egg_shark(m):
    base(m, '#6b97bd')
    m.ball((0, 1.7, 0.25), (3.2, 2.9, 3.5), '#f2f7fb')
    m.box((0, 5.9, -0.3), (0.3, 1.8, 1.4), '#4f7da3', rot=(25, 0, 0))
    for s in (-1, 1):
        m.box((s * 2.0, 3.0, 0.0), (0.2, 0.5, 1.4), '#4f7da3', rot=(0, 0, s * 40))
        m.ball((s * 0.8, 3.7, 1.7), 0.3, '#111111')
    for i in range(7):
        th = -40 + i * 13.5
        m.box(sp(th, -5), (0.3, 0.3, 0.3), '#ffffff', rot=(45, th, 0))


def egg_octopus(m):
    base(m, '#9a58c4')
    for th, ph in [(-40, 30), (40, 20), (0, -15), (80, -30), (-80, 0), (30, 55), (-30, -45), (120, 20)]:
        spot(m, th, ph, 0.38, '#f0b4e0')
    for i in range(8):
        a = math.radians(i * 45)
        m.ball((2.1 * math.sin(a), 0.6, 2.1 * math.cos(a)), (0.9, 1.0, 0.9), '#7e3fa6')
    for s in (-1, 1):
        m.ball((s * 0.8, 3.7, 1.72), 0.7, '#ffffff')
        m.ball((s * 0.8, 3.7, 2.0), 0.35, '#111111')


def egg_unicorn(m):
    cols = ['#ff8f8f', '#ffc98f', '#fff08f', '#a9f5a1', '#8fd0ff', '#c7a4ff']
    base(m, '#ffffff')
    for i, c in enumerate(cols):
        band(m, -55 + i * 22, 0.45, c, grow=0.0)
    for i in range(4):
        m.cyl((0, 5.5 + i * 0.35, 0), (1.0 - i * 0.22, 0.4, 1.0 - i * 0.22), '#ffe58a' if i % 2 else '#fff4c2', 'Neon')
    for s in (-1, 1):
        sparkle(m, s * 2.7, 4.5, 0.5, '#ffd1f0')
        sparkle(m, s * 2.2, 1.5, -1.0, '#c9f0ff', 0.35)


def egg_dragon(m):
    base(m, '#a8231c', 'Basalt' if False else 'Slate')
    for ph, n, off in [(40, 6, 0), (15, 7, 20), (-10, 7, 0), (-35, 6, 25), (-60, 5, 0)]:
        ring(m, ph, n, 0.5, '#62130f', off, 'Slate')
    for th, ph in [(-30, 20), (30, 5), (0, -25), (70, 30), (-70, -10)]:
        m.box(sp(th, ph), (0.14, 1.0, 0.18), '#ff9a1f', 'Neon', rot=(0, th, 30))
    for i in range(4):
        m.box((0, 5.0 - i * 0.05 + 0.4, -0.6 + i * 0.5 - 0.5), (0.4, 0.9, 0.4), '#2a0c0a', rot=(0, 0, 45))
    m.ball((0, 5.5, 0), (0.9, 1.4, 0.9), '#ff9a1f', 'Neon')
    m.ball((0, 6.1, 0), (0.5, 1.0, 0.5), '#ffe566', 'Neon')


EGGS = [
    ('Chicken Egg', 'Common', egg_chicken, 'Chicken'),
    ('Duck Egg', 'Common', egg_duck, 'Duck'),
    ('Pig Egg', 'Common', egg_pig, 'Pig'),
    ('Cow Egg', 'Common', egg_cow, 'Cow'),
    ('Sheep Egg', 'Common', egg_sheep, 'Sheep'),
    ('Bunny Egg', 'Uncommon', egg_bunny, 'Bunny'),
    ('Cat Egg', 'Uncommon', egg_cat, 'Cat'),
    ('Dog Egg', 'Uncommon', egg_dog, 'Dog'),
    ('Frog Egg', 'Uncommon', egg_frog, 'Frog'),
    ('Fox Egg', 'Uncommon', egg_fox, 'Fox'),
    ('Bear Egg', 'Uncommon', egg_bear, 'Bear'),
    ('Panda Egg', 'Rare', egg_panda, 'Panda'),
    ('Raccoon Egg', 'Rare', egg_raccoon, 'Raccoon'),
    ('Koala Egg', 'Rare', egg_koala, 'Koala'),
    ('Owl Egg', 'Rare', egg_owl, 'Owl'),
    ('Penguin Egg', 'Rare', egg_penguin, 'Penguin'),
    ('Turtle Egg', 'Rare', egg_turtle, 'Turtle'),
    ('Monkey Egg', 'Rare', egg_monkey, 'Monkey'),
    ('Zebra Egg', 'Epic', egg_zebra, 'Zebra'),
    ('Tiger Egg', 'Epic', egg_tiger, 'Tiger'),
    ('Lion Egg', 'Epic', egg_lion, 'Lion'),
    ('Giraffe Egg', 'Epic', egg_giraffe, 'Giraffe'),
    ('Elephant Egg', 'Epic', egg_elephant, 'Elephant'),
    ('Hippo Egg', 'Epic', egg_hippo, 'Hippo'),
    ('Wolf Egg', 'Epic', egg_wolf, 'Wolf'),
    ('Deer Egg', 'Epic', egg_deer, 'Deer'),
    ('Shark Egg', 'Legendary', egg_shark, 'Shark'),
    ('Octopus Egg', 'Legendary', egg_octopus, 'Octopus'),
    ('Unicorn Egg', 'Legendary', egg_unicorn, 'Unicorn'),
    ('Dragon Egg', 'Mythic', egg_dragon, 'Dragon'),
]


def build_egg(entry):
    name, tier, fn, _ = entry
    m = Model(name, tier)
    fn(m)
    if tier in ('Legendary', 'Mythic'):
        c = {'Legendary': '#ffe27a', 'Mythic': '#ff8a5c'}[tier]
        for i in range(4):
            a = math.radians(45 + i * 90)
            sparkle(m, 3.4 * math.sin(a), 3.0 + (i % 2) * 2.2, 3.4 * math.cos(a), c, 0.5)
    return m

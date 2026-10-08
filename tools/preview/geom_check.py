#!/usr/bin/env python3
"""Controlli geometrici sulla scena esportata: collisioni dentro il campo, porta libera, spawn liberi."""
import json, sys, math
import numpy as np

d = json.load(open(sys.argv[1]))
parts = []
def walk(nodes, path):
    for n in nodes:
        p = path + [n['n']]
        if n['c'] in ('Part', 'SpawnLocation', 'WedgePart', 'MeshPart') and 'Size' in n['p']:
            parts.append((p, n))
        walk(n.get('k', []), p)
walk(d['workspace'], [])
print('parti totali', len(parts))

def obb(n):
    c = n['p']['CFrame']; s = n['p']['Size']
    R = np.array([[c[3], c[4], c[5]], [c[6], c[7], c[8]], [c[9], c[10], c[11]]])
    return np.array(c[:3]), R, np.array(s) / 2

def overlaps(a, box_min, box_max):
    """SAT tra OBB e AABB."""
    ca, Ra, ha = a
    cb = (box_min + box_max) / 2
    hb = (box_max - box_min) / 2
    axes = [Ra[:, i] for i in range(3)] + [np.eye(3)[i] for i in range(3)]
    for i in range(3):
        for j in range(3):
            ax = np.cross(Ra[:, i], np.eye(3)[j])
            if np.linalg.norm(ax) > 1e-6: axes.append(ax / np.linalg.norm(ax))
    t = cb - ca
    for ax in axes:
        ra = sum(ha[i] * abs(np.dot(Ra[:, i], ax)) for i in range(3))
        rb = sum(hb[i] * abs(ax[i]) for i in range(3))
        if abs(np.dot(t, ax)) > ra + rb: return False
    return True

# volume di gioco (leggermente ridotto)
play_min = np.array([-120.5, 0.4, -69.5]); play_max = np.array([120.5, 44, 69.5])
allowed = {'Striscia', 'Palo', 'Traversa', 'RetePosteriore', 'ReteLato', 'ReteTetto', 'Vetro', 'Soffitto', 'Angolo'}
bad = 0
for path, n in parts:
    if not n['p'].get('CanCollide', True): continue
    if n['n'] in allowed: continue
    if overlaps(obb(n), play_min, play_max):
        bad += 1
        print('  DENTRO IL CAMPO:', '/'.join(path), [round(x, 1) for x in n['p']['CFrame'][:3]], [round(x, 1) for x in n['p']['Size']])
print('collidenti non previsti dentro il volume di gioco:', bad)

# bocca di porta libera (x oltre la linea di porta, z +-12, y 0.4..9)
for s in (-1, 1):
    gmin = np.array([min(s * 110.5, s * 118.5), 0.4, -12]); gmax = np.array([max(s * 110.5, s * 118.5), 9, 12])
    for path, n in parts:
        if not n['p'].get('CanCollide', True): continue
        if overlaps(obb(n), gmin, gmax) and n['n'] not in ('Striscia',):
            print('  Nella porta', s, '/'.join(path))

# spawn palla e calcio d'inizio
for name, pos in [('palla', (0, 1.7, 0))] + [('kick%d' % i, (x, 4, z)) for i, (x, z) in enumerate([(95, 0), (45, -26), (45, 26), (12, 0), (-95, 0), (-45, -26), (-45, 26), (-12, 0)])]:
    pmin = np.array(pos) - np.array([1.5, 0, 1.5]) + np.array([0, 0.5, 0]); pmax = np.array(pos) + np.array([1.5, 5, 1.5])
    for path, n in parts:
        if not n['p'].get('CanCollide', True): continue
        if n['n'] == 'Striscia': continue
        if overlaps(obb(n), pmin, pmax): print('  spawn', name, 'collide con', '/'.join(path))

# lobby: spawn e porta
Lc = [0, 60, -420]
for name, pos in [('lobbySpawn', (Lc[0], Lc[1] + 4, Lc[2] + 24))]:
    pmin = np.array(pos) - np.array([1.5, 4, 1.5]) + np.array([0, 0.5, 0]); pmax = np.array(pos) + np.array([1.5, 2, 1.5])
    for path, n in parts:
        if not n['p'].get('CanCollide', True): continue
        if overlaps(obb(n), pmin, pmax): print('  spawn', name, 'collide con', '/'.join(path))
# porta della baita: corridoio x +-10, z da -40 a +60, y 62..68
dmin = np.array([-10, 61.8, -410]); dmax = np.array([10, 68, -360])
for path, n in parts:
    if not n['p'].get('CanCollide', True): continue
    if overlaps(obb(n), dmin, dmax):
        print('  corridoio lobby bloccato da', '/'.join(path), [round(x, 1) for x in n['p']['CFrame'][:3]], [round(x, 1) for x in n['p']['Size']])

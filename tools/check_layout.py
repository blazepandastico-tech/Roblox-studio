#!/usr/bin/env python3
"""Controllo "il gioco resta uguale" per i ritocchi solo grafici.

  python3 tools/check_layout.py [riferimento git]   (predefinito: HEAD)
  python3 tools/check_layout.py --halloween         (gioco normale contro file di Halloween)

Costruisce la mappa (WorldBuilder) e una serie di giganti due volte con il Roblox finto delle prove:
con il codice del riferimento git e con quello attuale (tools/tests/layout_dump.luau). Poi confronta
tutto quello che conta per giocare:
  - le parti che si toccano o che i rampini/raggi colpiscono (CanCollide o CanQuery): posizione,
    misure, forma, nome, cartella, collisioni, ancoraggio, attributi;
  - i pezzi di terreno; gli oggetti con cui si interagisce (ProximityPrompt, sedili...);
  - le parti colpibili dei giganti (nuca, occhi, arti) e le loro giunture.
Le parti solo decorative (né collisione né query) possono cambiare liberamente: vengono solo contate.
Colori e materiali delle parti fisse sono grafica; per le parti NON ancorate il materiale cambia il
peso, quindi lì conta anche quello. Serve il programma 'luau' (variabile LUAU o nel PATH).
"""
import collections
import os
import shutil
import subprocess
import sys
import tarfile
import tempfile
import io

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))


def read(p):
    with open(p, encoding="utf-8") as f:
        return f.read()


def long_string(text):
    level = 1
    while ("]" + "=" * level + "]") in text:
        level += 1
    return "[" + "=" * level + "[\n" + text + "]" + "=" * level + "]"


def bundle_for(src_root, tema=None):
    sources = []
    for prefix, folder in (("Shared", os.path.join(src_root, "shared")), ("Server/Services", os.path.join(src_root, "server", "Services")), ("Client", os.path.join(src_root, "client"))):
        for base, _, names in os.walk(folder):
            for n in sorted(names):
                if n.endswith(".lua"):
                    rel = os.path.relpath(os.path.join(base, n), folder)[:-4].replace(os.sep, "/")
                    sources.append('\t["%s/%s"] = %s,' % (prefix, rel, long_string(read(os.path.join(base, n)))))
    bundle = "SOURCES_TABLE = {\n" + "\n".join(sources) + "\n}\n"
    for name in ("roblox_api.luau", "roblox_mock.luau"):
        bundle += read(os.path.join(ROOT, "tools", "tests", name)) + "\n"
    if tema:
        bundle += 'game:GetService("ReplicatedStorage"):SetAttribute("Tema", "%s")\n' % tema
    bundle += "do\n" + read(os.path.join(ROOT, "tools", "tests", "layout_dump.luau")) + "\nend\n"
    return bundle


def run(src_root, label, tema=None):
    luau = os.environ.get("LUAU") or shutil.which("luau")
    if not luau:
        sys.exit("Interprete 'luau' non trovato")
    with tempfile.NamedTemporaryFile("w", suffix=".luau", delete=False, encoding="utf-8") as f:
        f.write(bundle_for(src_root, tema))
        tmp = f.name
    proc = subprocess.run([luau, tmp], capture_output=True, text=True, timeout=1800)
    os.unlink(tmp)
    out = proc.stdout + proc.stderr
    if proc.returncode != 0 or "\nFINE" not in "\n" + out:
        sys.exit("Esportazione (%s) non riuscita:\n%s" % (label, out[-3000:]))
    return out.splitlines()


def extract(ref, dest):
    data = subprocess.run(["git", "-C", ROOT, "archive", ref, "src"], capture_output=True, check=True).stdout
    with tarfile.open(fileobj=io.BytesIO(data)) as tar:
        tar.extractall(dest, filter="data") if hasattr(tarfile, "data_filter") else tar.extractall(dest)
    return os.path.join(dest, "src")


# campi di una riga P / GP / GD (vedi layout_dump.luau)
P_PATH, P_NAME, P_CLASS, P_SHAPE, P_SIZE, P_CF, P_COLLIDE, P_QUERY, P_TOUCH, P_GROUP, P_ANCHORED, P_MASSLESS, P_PHYS, P_ATTRS, P_TRANSP, P_MAT, P_COLOR = range(1, 18)


def gameplay_key(f):
    key = [f[P_PATH], f[P_NAME], f[P_CLASS], f[P_SHAPE], f[P_SIZE], f[P_CF], f[P_COLLIDE], f[P_QUERY], f[P_TOUCH], f[P_GROUP], f[P_ANCHORED], f[P_MASSLESS], f[P_PHYS], f[P_ATTRS]]
    if f[P_ANCHORED] != "true":
        key.append(f[P_MAT])  # il materiale decide il peso delle parti libere
    return tuple(key)


def parse(lines):
    world = collections.Counter()  # parti che contano per il gioco
    look = {}  # stessa parte -> (trasparenza, materiale, colore), per contare i ritocchi
    deco = 0
    deco_touch = 0  # decorazioni che hanno ancora CanTouch (innocue, ma da segnalare)
    interactive = collections.Counter()
    terrain = collections.Counter()
    titans = collections.Counter()
    titan_deco = 0
    errors = []
    for line in lines:
        f = line.split("\t")
        tag = f[0]
        if tag == "P":
            if len(f) < 18:
                errors.append(line)
                continue
            if f[P_COLLIDE] == "true" or f[P_QUERY] == "true":
                k = gameplay_key(f)
                world[k] += 1
                look[k] = (f[P_TRANSP], f[P_MAT], f[P_COLOR])
            else:
                deco += 1
                if f[P_TOUCH] == "true":
                    deco_touch += 1
        elif tag == "I":
            interactive[tuple(f[1:])] += 1
        elif tag == "T":
            terrain[tuple(f[1:])] += 1
        elif tag == "G":
            titans[("G", f[1])] += 1
        elif tag == "GX":
            titans[("GX", f[1], f[2] if len(f) > 2 else "")] += 1
        elif tag == "GP":
            titans[gameplay_key(f)] += 1
        elif tag == "GM":
            titans[tuple(f)] += 1
        elif tag == "GD":
            titan_deco += 1
    return {"world": world, "look": look, "deco": deco, "deco_touch": deco_touch, "interactive": interactive, "terrain": terrain, "titans": titans, "titan_deco": titan_deco, "errors": errors}


def diff(name, old, new, show=6):
    gone = old - new
    added = new - old
    if not gone and not added:
        return 0
    print("  %s: %d spariti, %d nuovi" % (name, sum(gone.values()), sum(added.values())))
    for k in list(gone)[:show]:
        print("    - " + " | ".join(k)[:300])
    for k in list(added)[:show]:
        print("    + " + " | ".join(k)[:300])
    return sum(gone.values()) + sum(added.values())


def main():
    args = sys.argv[1:]
    if "--halloween" in args:
        # stesso codice, due temi: il file di Halloween deve avere la stessa mappa di gioco
        ref = "normale"
        print("costruisco il gioco normale...")
        old = parse(run(os.path.join(ROOT, "src"), ref))
        print("costruisco il gioco di Halloween...")
        new = parse(run(os.path.join(ROOT, "src"), "Halloween", "Halloween"))
    else:
        ref = args[0] if args else "HEAD"
        with tempfile.TemporaryDirectory() as tmp:
            old_src = extract(ref, tmp)
            print("costruisco il gioco di %s..." % ref)
            old = parse(run(old_src, ref))
        print("costruisco il gioco attuale...")
        new = parse(run(os.path.join(ROOT, "src"), "attuale"))
    for label, data in ((ref, old), ("attuale", new)):
        if data["errors"]:
            print("righe non riconosciute (%s): %d" % (label, len(data["errors"])))
    problems = 0
    problems += diff("parti del mondo che contano per il gioco", old["world"], new["world"])
    problems += diff("terreno", old["terrain"], new["terrain"])
    problems += diff("oggetti interattivi", old["interactive"], new["interactive"])
    problems += diff("giganti (parti colpibili e giunture)", old["titans"], new["titans"])
    restyled = sum(1 for k, v in new["look"].items() if k in old["look"] and old["look"][k] != v)
    print("parti di gioco: %d (stesse posizioni e collisioni), ritoccate nell'aspetto: %d" % (sum(new["world"].values()), restyled))
    print("decorazioni del mondo: %d -> %d (%+d)" % (old["deco"], new["deco"], new["deco"] - old["deco"]))
    print("decorazioni dei giganti: %d -> %d (%+d)" % (old["titan_deco"], new["titan_deco"], new["titan_deco"] - old["titan_deco"]))
    if new["deco_touch"] > old["deco_touch"]:
        print("nota: %d decorazioni nuove hanno ancora CanTouch attivo" % (new["deco_touch"] - old["deco_touch"]))
    if problems:
        print("ATTENZIONE: %d differenze in quello che conta per il gioco" % problems)
        sys.exit(1)
    print("Mappa identica: posizioni, collisioni, terreno, interazioni e giganti non cambiano.")


if __name__ == "__main__":
    main()

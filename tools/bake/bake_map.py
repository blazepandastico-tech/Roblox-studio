#!/usr/bin/env python3
"""Scrive la mappa gia' costruita DENTRO il file CalcioFuorilegge.rbxlx, cosi' si vede in Studio anche senza premere Play.

Come funziona (tutto senza Roblox Studio):
  1. esegue MapBuilder.BuildStatic() nello shim Roblox (tools/preview/robloxshim.lua) -> albero di istanze di workspace.World,
     Lighting e Terrain (solo proprieta' e figli: i voxel del terreno NON si salvano nel file, si costruiscono all'avvio);
  2. export_world.lua lo scrive come righe di testo (istanze, proprieta', attributi, tag);
  3. gli script di src/ diventano righe dello stesso tipo;
  4. rbxbake (Rust, con le librerie ufficiali rbx_xml / rbx_reflection_database di Rojo) controlla ogni proprieta' contro
     l'API vera di Roblox e scrive il .rbxlx;
  5. controllo finale: il file viene riletto in modo rigoroso e confrontato con i record di partenza.

Requisiti: python3 con `lupa`, tools/preview/api_index.lua (python3 tools/preview/build_api_index.py), toolchain Rust
e il repository rbx-dom di Rojo (vedi Cargo.toml di rbxbake, percorso configurabile con RBX_DOM).

uso: bake_map.py [--out CalcioFuorilegge.rbxlx] [--keep cartella]
"""
import argparse
import math
import os
import re
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
SRC = os.path.join(ROOT, "src")
PREVIEW = os.path.join(ROOT, "tools", "preview")
WORLD_BASE = 100000  # gli id dei record degli script partono da 1, quelli del mondo da qui

SERVICES = ["ReplicatedStorage", "ServerScriptService", "StarterPlayer"]
SPECIAL_CLASSES = {"StarterPlayerScripts": "StarterPlayerScripts", "StarterCharacterScripts": "StarterCharacterScripts"}


def enc(s):
    if s == "":
        return "~"
    return "".join(chr(b) if (chr(b).isascii() and (chr(b).isalnum() or chr(b) in "._-")) else "%%%02X" % b for b in s.encode("utf-8"))


# ------------------------------------------------------------------ 1-2. mondo dallo shim
def export_world(api_index, out_path):
    from lupa import LuaRuntime

    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.globals().API_INDEX_PATH = api_index
    lua.execute(open(os.path.join(PREVIEW, "robloxshim.lua"), encoding="utf-8").read())
    files = []
    for dp, _, fn in os.walk(SRC):
        for f in fn:
            if f.endswith(".lua"):
                files.append(os.path.relpath(os.path.join(dp, f), SRC))
    lua.execute("function __mount(root, ...) __SHIM.mountFiles(root, {...}) end")
    lua.globals().__mount(SRC, *sorted(files))
    lua.globals().EXPORT_LUA = os.path.join(HERE, "export_world.lua")
    lua.globals().OUT_PATH = out_path
    lua.globals().WORLD_BASE = WORLD_BASE
    res = lua.execute(
        r'''
local Server = game:GetService("ServerScriptService"):WaitForChild("Server")
local MapBuilder = require(Server:WaitForChild("MapBuilder"))
local world = MapBuilder.BuildStatic()
world:SetAttribute("Baked", true)
local Lighting = game:GetService("Lighting")
-- Technology non si puo' impostare da script, solo dal file: ombre dal sole e dai faretti (ShadowMap)
rawget(Lighting, "_p").Technology = Enum.Technology.ShadowMap
local Exp = assert(loadfile(EXPORT_LUA))()
local n = Exp.export({
	{ inst = world, under = "Workspace" },
	{ inst = workspace.Terrain, under = "Workspace" },
	{ inst = Lighting, is = "Lighting" },
}, OUT_PATH, { base = WORLD_BASE })
return n .. " istanze esportate | problemi dello shim: " .. (#__SHIM.problems == 0 and "nessuno" or table.concat(__SHIM.problems, "; "))
'''
    )
    return res


# ------------------------------------------------------------------ 3. script
class Records:
    def __init__(self):
        self.n = 0
        self.lines = []

    def inst(self, parent, cls, name):
        self.n += 1
        self.lines.append("I %d %d %s %s" % (self.n, parent, cls, enc(name)))
        return self.n

    def prop(self, i, name, kind, data):
        self.lines.append("P %d %s %s %s" % (i, name, kind, data))


def add_dir(rec, parent, path):
    for entry in sorted(os.listdir(path)):
        full = os.path.join(path, entry)
        if os.path.isdir(full):
            i = rec.inst(parent, SPECIAL_CLASSES.get(entry, "Folder"), entry)
            add_dir(rec, i, full)
        elif entry.endswith(".lua"):
            src = open(full, encoding="utf-8").read()
            if entry.endswith(".server.lua"):
                cls, name = "Script", entry[: -len(".server.lua")]
            elif entry.endswith(".client.lua"):
                cls, name = "LocalScript", entry[: -len(".client.lua")]
            else:
                cls, name = "ModuleScript", entry[: -len(".lua")]
            i = rec.inst(parent, cls, name)
            rec.prop(i, "Source", "s", enc(src))


def script_records(out_path):
    rec = Records()
    # Players resta com'e': CharacterAutoLoads e' acceso, cosi' il personaggio compare nella lobby (SpawnLocation) anche se uno script
    # non parte; Main.server.lua lo spegne appena parte, poi il personaggio lo carica Match
    for folder in SERVICES:
        path = os.path.join(SRC, folder)
        if os.path.isdir(path):
            svc = rec.inst(0, folder, folder)
            rec.lines.append("S %s %d" % (folder, svc))
            add_dir(rec, svc, path)
    open(out_path, "w", encoding="utf-8").write("\n".join(rec.lines) + "\n")
    return rec.n


# ------------------------------------------------------------------ 4-5. scrittura e controllo
def protect_sources(xml):
    """Studio scrive il testo degli script come <ProtectedString name="Source">; rbx_xml lo scrive come <string>. Si riscrive come Studio:
    cosi' il file e' identico a uno salvato da Studio anche su questo punto. Restituisce (xml, quanti)."""
    start_tag = '<string name="Source">'
    out, pos, n = [], 0, 0
    while True:
        i = xml.find(start_tag, pos)
        if i < 0:
            out.append(xml[pos:])
            break
        out.append(xml[pos:i])
        k = i + len(start_tag)
        if xml.startswith("<![CDATA[", k):
            while True:  # una o piu' sezioni CDATA di fila (rbx_xml spezza il contenuto se contiene "]]>")
                e = xml.index("]]>", k) + 3
                k = e
                if xml.startswith("<![CDATA[", k):
                    continue
                break
            assert xml.startswith("</string>", k), "fine inattesa dell'elemento Source"
        else:
            k = xml.index("</string>", k)
        out.append('<ProtectedString name="Source">' + xml[i + len(start_tag):k] + "</ProtectedString>")
        pos = k + len("</string>")
        n += 1
    return "".join(out), n



def find_rbxbake():
    exe = os.path.join(HERE, "rbxbake", "target", "release", "rbxbake")
    if os.path.exists(exe):
        return exe
    print("compilo rbxbake...")
    subprocess.check_call(["cargo", "build", "--release"], cwd=os.path.join(HERE, "rbxbake"))
    return exe


FLOAT_RE = re.compile(r"^-?\d+(\.\d+)?([eE][-+]?\d+)?$")


def same_token(a, b, tol=2e-6):
    if a == b:
        return True
    if FLOAT_RE.match(a) and FLOAT_RE.match(b):
        x, y = float(a), float(b)
        return math.isclose(x, y, rel_tol=tol, abs_tol=tol)
    return False


# classi con il colore salvato a 8 bit per canale (Color3uint8): il file ha il colore arrotondato a n/255, come fa Studio
PARTS = {"Part", "SpawnLocation", "WedgePart", "MeshPart", "TrussPart", "UnionOperation", "Seat", "VehicleSeat", "CornerWedgePart"}
# proprieta' che l'encoder ufficiale riscrive con un altro nome / forma: (nome nel file di partenza -> nome nel file riletto)
RENAMED = {"Font": "FontFace", "Texture": "TextureContent"}


def norm_records(lines):
    """chiave -> lista di righe, ignorando l'ordine delle proprieta' e il nome del tipo di enum (la lettura lo conosce solo come numero)"""
    out = {}
    for ln in lines:
        t = ln.split()
        if not t or t[0].startswith("#") or t[0] in ("S", "U"):
            continue
        if t[0] == "P" and t[3] == "e":
            t = t[:4] + ["-"] + t[5:]
        if t[0] in ("P", "A"):
            key = (t[0], t[1], t[2])
        elif t[0] == "T":
            key = ("T", t[1], t[2])
        else:
            key = ("I", t[1], "")
        out.setdefault(key, []).append(t)
    return out


def compare(original, dumped, id_map):
    """Confronta i record esportati con quelli riletti dal file. id_map: id esportato -> id riletto."""
    problems = []
    cls_of = {}
    for ln in original:
        t = ln.split()
        if t and t[0] == "I":
            cls_of[int(t[1])] = t[3]
    a = norm_records(original)
    b = norm_records(dumped)
    expected = set()
    for key, rows in a.items():
        mapped = id_map.get(int(key[1]))
        if mapped is None:
            problems.append("istanza non ritrovata nel file: id %s (%s)" % (key[1], " ".join(rows[0])[:100]))
            continue
        name = key[2]
        if key[0] == "P" and name in RENAMED:
            name = RENAMED[name]
        k2 = (key[0], str(mapped), name)
        expected.add(k2)
        got = b.get(k2)
        if got is None:
            problems.append("manca nel file: %s" % " ".join(rows[0])[:160])
            continue
        r, g = rows[0], got[0]
        if key[0] == "I":
            if r[3:] != g[3:]:
                problems.append("istanza diversa: %s  <->  %s" % (" ".join(r)[:100], " ".join(g)[:100]))
            continue
        if key[0] == "T":
            continue
        if key[0] == "P" and key[2] == "Font":
            if g[3] != "font":
                problems.append("carattere non migrato: %s" % " ".join(g)[:100])
            continue
        rv, gv = r[3:], g[3:]
        if r[3] == "r":
            # riferimento: l'id va tradotto
            if len(rv) != 2 or id_map.get(int(rv[1])) != int(gv[1]):
                problems.append("riferimento diverso: %s  <->  %s" % (" ".join(r)[:100], " ".join(g)[:100]))
            continue
        tol = 2e-6
        if key[0] == "P" and name == "Color" and rv[0] == "c3" and cls_of[int(key[1])] in PARTS:
            tol = 0.5 / 255 + 1e-6
            if len(rv) == len(gv) and not all(same_token(x, y, tol) for x, y in zip(rv, gv)):
                problems.append("colore troppo diverso: %s  <->  %s" % (" ".join(r)[:120], " ".join(g)[:120]))
            continue
        if len(rv) != len(gv) or not all(same_token(x, y, tol) for x, y in zip(rv, gv)):
            problems.append("valore diverso: %s  <->  %s" % (" ".join(r)[:120], " ".join(g)[:120]))
    extra = [k for k in b if k[0] in ("P", "A", "T") and k not in expected]
    return problems, extra


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=os.path.join(ROOT, "CalcioFuorilegge.rbxlx"))
    ap.add_argument("--api-index", default=os.path.join(PREVIEW, "api_index.lua"))
    ap.add_argument("--keep", default=None, help="cartella dove lasciare i file intermedi")
    args = ap.parse_args()
    if not os.path.exists(args.api_index):
        sys.exit("manca %s: esegui prima  python3 tools/preview/build_api_index.py" % args.api_index)
    work = args.keep or os.path.join(HERE, "_work")
    os.makedirs(work, exist_ok=True)
    world_txt = os.path.join(work, "world.records")
    script_txt = os.path.join(work, "scripts.records")
    tmp_out = os.path.join(work, "bake.rbxlx")
    tmp_bin = os.path.join(work, "bake.rbxl")
    out_bin = os.path.splitext(args.out)[0] + ".rbxl"

    print("1/5 costruisco la mappa nello shim ed esporto:", export_world(args.api_index, world_txt))
    print("2/5 script del progetto:", script_records(script_txt), "oggetti")
    exe = find_rbxbake()
    print("3/5 scrivo i file con rbxbake (XML .rbxlx e binario .rbxl)")
    subprocess.check_call([exe, "build", script_txt, world_txt, "-o", tmp_out, "--binary", tmp_bin])
    shutil.copyfile(tmp_bin, out_bin)

    # intestazione come quella scritta da Studio (rbx_xml scrive solo <roblox version="4">)
    xml = open(tmp_out, encoding="utf-8").read()
    head = '<roblox version="4">'
    assert xml.startswith(head), xml[:80]
    xml = (
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
        'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">\n'
        '\t<Meta name="ExplicitAutoJoints">true</Meta>' + xml[len(head):]
    )
    xml, n_sources = protect_sources(xml)
    print("   %d script scritti come ProtectedString" % n_sources)
    open(args.out, "w", encoding="utf-8").write(xml)

    # ids riletti: preordine su tutto il file; ids esportati: script 1..N, mondo WORLD_BASE+1.. -> stesso preordine per servizio
    original = open(script_txt, encoding="utf-8").read().splitlines() + open(world_txt, encoding="utf-8").read().splitlines()
    problems = []
    for label, path in (("XML", args.out), ("binario", out_bin)):
        print("4/5 rileggo il file %s in modo rigoroso (proprieta' sconosciute = errore)" % label)
        dumped = subprocess.run([exe, "dump", path], check=True, capture_output=True, text=True).stdout.splitlines()
        id_map = build_id_map(original, dumped)
        probs, extra = compare(original, dumped, id_map)
        print("5/5 %s: confronto con i record di partenza: %d differenze, %d proprieta' in piu' nel file" % (label, len(probs), len(extra)))
        for p in probs[:30]:
            print("   ", p)
        for k in extra[:15]:
            print("    in piu':", k)
        problems += probs
        print("scritto %s (%.2f MiB)" % (path, os.path.getsize(path) / 1048576))
    if args.keep is None:
        shutil.rmtree(work, ignore_errors=True)
    return 1 if problems else 0


def build_id_map(original, dumped):
    """Collega gli id esportati a quelli riletti con (classe, nome, percorso dei nomi)."""
    def paths(lines):
        info = {}
        order = []
        under = {}
        for ln in lines:
            t = ln.split()
            if not t:
                continue
            if t[0] == "I":
                info[int(t[1])] = (int(t[2]), t[3], t[4])
                order.append(int(t[1]))
            elif t[0] == "U":
                under[int(t[1])] = t[2]  # radice che sta dentro un servizio
        out = {}
        for i in order:
            chain = []
            j = i
            while j:
                par, cls, name = info[j]
                chain.append((cls, name))
                if not par and j in under:
                    chain.append((under[j], under[j]))
                j = par
            out[i] = tuple(reversed(chain))
        return out, order

    po, oo = paths(original)
    pd, od = paths(dumped)
    # nello stesso padre possono esserci fratelli omonimi: si accoppia per ordine
    by_path = {}
    for i in od:
        by_path.setdefault(pd[i], []).append(i)
    seen = {}
    m = {}
    for i in oo:
        p = po[i]
        # i servizi sono nodi radice: nel file ci sono sempre e partono col nome del servizio
        k = seen.get(p, 0)
        seen[p] = k + 1
        cand = by_path.get(p)
        if cand is None or k >= len(cand):
            continue
        m[i] = cand[k]
    return m


if __name__ == "__main__":
    sys.exit(main())

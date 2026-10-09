#!/usr/bin/env python3
"""Prova di costruzione del mondo fuori da Roblox Studio.
Costruisce tutta la mappa (WorldBuilder), i forzieri, un cavallo e una barca con un Roblox finto
che controlla ogni proprietà con l'elenco ufficiale di Roblox (tools/tests/roblox_api.luau).
Uso:  python3 tools/test_world.py   (serve il programma 'luau' nel PATH o nella variabile LUAU)"""
import os, shutil, subprocess, sys, tempfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))

def read(p):
    with open(p, encoding="utf-8") as f:
        return f.read()

def long_string(text):
    level = 1
    while ("]" + "=" * level + "]") in text:
        level += 1
    return "[" + "=" * level + "[\n" + text + "]" + "=" * level + "]"

sources = []
for prefix, folder in (("Shared", os.path.join(ROOT, "src", "shared")), ("Server/Services", os.path.join(ROOT, "src", "server", "Services")), ("Client", os.path.join(ROOT, "src", "client"))):
    for base, _, names in os.walk(folder):
        for n in sorted(names):
            if n.endswith(".lua"):
                rel = os.path.relpath(os.path.join(base, n), folder)[:-4].replace(os.sep, "/")
                sources.append('\t["%s/%s"] = %s,' % (prefix, rel, long_string(read(os.path.join(base, n)))))
bundle = "SOURCES_TABLE = {\n" + "\n".join(sources) + "\n}\n"
bundle += read(os.path.join(ROOT, "tools", "tests", "roblox_api.luau")) + "\n"
bundle += read(os.path.join(ROOT, "tools", "tests", "roblox_mock.luau")) + "\n"
bundle += "do\n" + read(os.path.join(ROOT, "tools", "tests", "world_smoke.luau")) + "\nend\n"
bundle += "do\n" + read(os.path.join(ROOT, "tools", "tests", "client_smoke.luau")) + "\nend\n"

luau = os.environ.get("LUAU") or shutil.which("luau")
if not luau:
    print("Interprete 'luau' non trovato: scaricalo da https://github.com/luau-lang/luau/releases")
    sys.exit(2)
with tempfile.NamedTemporaryFile("w", suffix=".luau", delete=False, encoding="utf-8") as f:
    f.write(bundle)
    path = f.name
proc = subprocess.run([luau, path], capture_output=True, text=True)
os.unlink(path)
print((proc.stdout + proc.stderr).strip())
sys.exit(0 if proc.returncode == 0 else 1)

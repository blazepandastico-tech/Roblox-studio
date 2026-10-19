#!/usr/bin/env python3
"""Esegue i controlli di coerenza dei dati (tools/tests/data_checks.luau) con l'interprete luau,
più alcuni controlli incrociati tra file (filmati, aspetti dei giganti, animazioni).
Uso:  python3 tools/test_data.py   (serve il programma 'luau' nel PATH o nella variabile LUAU)"""
import os, re, shutil, subprocess, sys, tempfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
SHARED = os.path.join(ROOT, "src", "shared")

def read(p):
    with open(p, encoding="utf-8") as f:
        return f.read()

def long_string(text):
    level = 1
    while ("]" + "=" * level + "]") in text:
        level += 1
    return "[" + "=" * level + "[\n" + text + "]" + "=" * level + "]"

sources = []
for base, _, names in os.walk(SHARED):
    for n in sorted(names):
        if n.endswith(".lua"):
            rel = os.path.relpath(os.path.join(base, n), SHARED)[:-4].replace(os.sep, "/")
            sources.append('\t["%s"] = %s,' % (rel, long_string(read(os.path.join(base, n)))))
bundle = "SOURCES_TABLE = {\n" + "\n".join(sources) + "\n}\n"
bundle += read(os.path.join(ROOT, "tools", "tests", "stubs.luau")) + "\n"
bundle += "do\n" + read(os.path.join(ROOT, "tools", "tests", "data_checks.luau")) + "\nend\n"

luau = os.environ.get("LUAU") or shutil.which("luau")
if not luau:
    print("Interprete 'luau' non trovato: scaricalo da https://github.com/luau-lang/luau/releases")
    sys.exit(2)
with tempfile.NamedTemporaryFile("w", suffix=".luau", delete=False, encoding="utf-8") as f:
    f.write(bundle)
    path = f.name
proc = subprocess.run([luau, path], capture_output=True, text=True)
os.unlink(path)
out = proc.stdout + proc.stderr
errors = []
cutscenes = set()
for line in out.splitlines():
    if line.startswith("CUTSCENES:"):
        cutscenes = set(filter(None, line[len("CUTSCENES:"):].split(",")))
    else:
        print(line)
if proc.returncode != 0:
    errors.append("controlli Luau falliti")

# controlli incrociati con il codice del client e del server
cut = read(os.path.join(ROOT, "src", "client", "Controllers", "CutsceneController.lua"))
scenes = set(re.findall(r"^Scenes\.(\w+) = function", cut, re.M))
for c in sorted(cutscenes - scenes):
    errors.append(f"Filmato '{c}' usato dalla storia ma non definito in CutsceneController")

builder = read(os.path.join(SHARED, "Anim", "TitanBuilder.lua"))
looks = set(re.findall(r'look == "(\w+)"', builder)) | {"Puro", "Sagoma"}
for f in ("Titans.lua", "Serums.lua"):
    for look in re.findall(r'Look = "(\w+)"', read(os.path.join(SHARED, "Data", f))):
        if look not in looks:
            errors.append(f"{f}: aspetto '{look}' sconosciuto a TitanBuilder")
for look in re.findall(r'api\.Titan\("(\w+)"', cut):
    if look not in looks:
        errors.append(f"CutsceneController: aspetto '{look}' sconosciuto a TitanBuilder")

poses = read(os.path.join(SHARED, "Anim", "Poses.lua"))
clips = set(re.findall(r'clip\("(\w+)"', poses))
for base, _, names in os.walk(os.path.join(ROOT, "src", "client")):
    for n in names:
        text = read(os.path.join(base, n))
        for name in re.findall(r'(?:AnimationController\.Play\([^,]+,|api\.Animate\([^,]+,)\s*"(\w+)"(?!\s*\.\.)', text):
            if name not in clips:
                errors.append(f"{n}: animazione '{name}' inesistente in Poses")

shifter = read(os.path.join(ROOT, "src", "server", "Services", "ShifterService.lua"))
kinds = set(re.findall(r'kind == "(\w+)"', shifter))
for k in set(re.findall(r'Kind = "(\w+)"', read(os.path.join(SHARED, "Data", "Serums.lua")))):
    if k not in kinds:
        errors.append(f"Serums: tipo di abilità '{k}' non gestito da ShifterService")

if errors:
    for e in errors:
        print("ERRORE:", e)
    sys.exit(1)
print("Controlli incrociati dei dati OK")

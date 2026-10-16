#!/usr/bin/env python3
"""Controlli incrociati del progetto (eseguito in fase di verifica):
 - ogni chiamata S.<Servizio>.<Funzione> deve esistere nel servizio
 - ogni Net.Event/Unreliable/Function("Nome") deve essere dichiarato in Net.lua
 - ogni require(script.Parent.X) / Shared.X deve puntare a un file esistente
"""
import os, re, sys

ROOT = os.path.join(os.path.dirname(__file__), "..")
SRC = os.path.join(ROOT, "src")
errors = []

def read(path):
    with open(path, encoding="utf-8") as f:
        return f.read()

files = []
for base, _, names in os.walk(SRC):
    for n in names:
        if n.endswith(".lua"):
            files.append(os.path.join(base, n))

# 1) servizi del server e controller del client
def module_members(path, modname):
    text = read(path)
    members = set(re.findall(r"function\s+%s[.:](\w+)\s*\(" % re.escape(modname), text))
    members |= set(re.findall(r"^%s\.(\w+)\s*=" % re.escape(modname), text, re.M))
    return members

registries = {
    "S": [os.path.join(SRC, "server", "Services")],
    "C": [os.path.join(SRC, "client", "Controllers"), os.path.join(SRC, "client", "UI")],
}
for var, folders in registries.items():
    members = {}
    for folder in folders:
        if not os.path.isdir(folder):
            continue
        for n in os.listdir(folder):
            if n.endswith(".lua"):
                name = n[:-4]
                members[name] = module_members(os.path.join(folder, n), name)
    for path in files:
        text = read(path)
        for svc, fn in re.findall(r"\b%s\.(\w+)\.(\w+)" % var, text):
            if svc not in members:
                # potrebbe essere un'altra tabella chiamata S/C: segnala solo se la cartella combacia
                if (var == "S" and "/server/" in path) or (var == "C" and "/client/" in path):
                    errors.append(f"{os.path.relpath(path, ROOT)}: modulo inesistente {var}.{svc}")
                continue
            if fn not in members[svc]:
                errors.append(f"{os.path.relpath(path, ROOT)}: {var}.{svc}.{fn} non esiste")

# 1b) l'elenco ORDER dei due Main deve puntare a moduli esistenti
for main, pattern in (
    (os.path.join(SRC, "server", "Main.server.lua"), r'^\s*"(\w+)",?\s*$'),
    (os.path.join(SRC, "client", "Main.client.lua"), r'\{\s*(\w+),\s*"(\w+)"\s*\}'),
):
    if not os.path.exists(main):
        continue
    text = read(main)
    block = re.search(r"local ORDER = \{(.*?)\n\}", text, re.S)
    if not block:
        errors.append(f"{os.path.relpath(main, ROOT)}: ORDER non trovato")
        continue
    for m in re.finditer(pattern, block.group(1), re.M):
        if len(m.groups()) == 2:
            folder = {"Controllers": "Controllers", "UI": "UI"}.get(m.group(1), m.group(1))
            target = os.path.join(SRC, "client", folder, m.group(2) + ".lua")
        else:
            target = os.path.join(SRC, "server", "Services", m.group(1) + ".lua")
        if not os.path.exists(target):
            errors.append(f"{os.path.relpath(main, ROOT)}: modulo in ORDER inesistente: {os.path.relpath(target, ROOT)}")

# 2) remote
net = read(os.path.join(SRC, "shared", "Lib", "Net.lua"))
def names_in(block):
    m = re.search(r"Net\.%s\s*=\s*\{(.*?)\n\}" % block, net, re.S)
    return set(re.findall(r'"(\w+)"', m.group(1))) if m else set()
events, unreliable, functions = names_in("EventNames"), names_in("UnreliableNames"), names_in("FunctionNames")
for path in files:
    text = read(path)
    for kind, name in re.findall(r'Net\.(Event|Unreliable|Function)\("(\w+)"\)', text):
        pool = {"Event": events, "Unreliable": unreliable, "Function": functions}[kind]
        if name not in pool:
            errors.append(f"{os.path.relpath(path, ROOT)}: Net.{kind}(\"{name}\") non dichiarato in Net.lua")

# 3) require dei moduli condivisi (Shared.X.Y)
for path in files:
    text = read(path)
    for chain in re.findall(r"require\(Shared((?:\.\w+)+)\)", text):
        parts = chain.strip(".").split(".")
        target = os.path.join(SRC, "shared", *parts)
        if not (os.path.exists(target + ".lua") or os.path.isdir(target)):
            errors.append(f"{os.path.relpath(path, ROOT)}: require(Shared{chain}) non trovato")
    for chain in re.findall(r"require\(script\.Parent((?:\.\w+)+)\)", text):
        parts = chain.strip(".").split(".")
        here = os.path.dirname(path)
        while parts and parts[0] == "Parent":
            here = os.path.dirname(here)
            parts = parts[1:]
        target = os.path.join(here, *parts)
        if not (os.path.exists(target + ".lua") or os.path.isdir(target)):
            errors.append(f"{os.path.relpath(path, ROOT)}: require(script.Parent{chain}) non trovato")

if errors:
    print("\n".join(sorted(set(errors))))
    sys.exit(1)
print("Riferimenti incrociati OK (%d file)" % len(files))

#!/usr/bin/env python3
"""Impacchetta la cartella src/ in un place Roblox (.rbxlx) apribile con Roblox Studio: versione LEGGERA, con i soli script.
La mappa non e' nel file: si costruisce da codice quando parte il gioco (MapBuilder.Build).
Per il file completo, con la mappa gia' dentro e visibile anche prima di premere Play, usa  python3 tools/bake/bake_map.py

Convenzioni (le stesse di Rojo):
  *.server.lua -> Script
  *.client.lua -> LocalScript
  *.lua        -> ModuleScript
  cartelle     -> Folder (o servizio, se al primo livello)
"""
import os
import sys
from xml.sax.saxutils import escape

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "src")
OUT = os.path.join(ROOT, "CalcioFuorilegge_solo_script.rbxlx")

# nome cartella -> classe del servizio
SERVICES = {
    "ReplicatedStorage": "ReplicatedStorage",
    "ServerScriptService": "ServerScriptService",
    "StarterPlayer": "StarterPlayer",
}
SPECIAL_CLASSES = {"StarterPlayerScripts": "StarterPlayerScripts", "StarterCharacterScripts": "StarterCharacterScripts"}

_counter = 0


def ref():
    global _counter
    _counter += 1
    return "RBX%d" % _counter


def cdata(src):
    return "<![CDATA[" + src.replace("]]>", "]]]]><![CDATA[>") + "]]>"


def script_item(cls, name, source):
    props = '<string name="Name">%s</string>' % escape(name)
    if cls in ("Script", "LocalScript"):
        props += '<bool name="Disabled">false</bool>'
    props += '<ProtectedString name="Source">%s</ProtectedString>' % cdata(source)
    return '<Item class="%s" referent="%s"><Properties>%s</Properties></Item>' % (cls, ref(), props)


def container_item(cls, name, children_xml, extra_props=""):
    props = '<string name="Name">%s</string>%s' % (escape(name), extra_props)
    return '<Item class="%s" referent="%s"><Properties>%s</Properties>%s</Item>' % (cls, ref(), props, children_xml)


def build_dir(path, top=False):
    xml = []
    for entry in sorted(os.listdir(path)):
        full = os.path.join(path, entry)
        if os.path.isdir(full):
            cls = SPECIAL_CLASSES.get(entry, "Folder")
            xml.append(container_item(cls, entry, build_dir(full)))
        elif entry.endswith(".lua"):
            with open(full, encoding="utf-8") as f:
                source = f.read()
            if entry.endswith(".server.lua"):
                xml.append(script_item("Script", entry[: -len(".server.lua")], source))
            elif entry.endswith(".client.lua"):
                xml.append(script_item("LocalScript", entry[: -len(".client.lua")], source))
            else:
                xml.append(script_item("ModuleScript", entry[: -len(".lua")], source))
    return "".join(xml)


def main():
    items = []
    items.append(container_item("Workspace", "Workspace", ""))
    items.append(
        container_item("Players", "Players", "", '<bool name="CharacterAutoLoads">false</bool>')
    )
    # Luce con ombre dal sole e dai faretti (ShadowMap = 3). Technology non si puo' impostare da script, solo dal file.
    items.append(container_item("Lighting", "Lighting", "", '<token name="Technology">3</token>'))
    for folder, cls in SERVICES.items():
        path = os.path.join(SRC, folder)
        if os.path.isdir(path):
            items.append(container_item(cls, folder, build_dir(path, True)))
    xml = (
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" '
        'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
        'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">\n'
        '<Meta name="ExplicitAutoJoints">true</Meta>\n'
        + "\n".join(items)
        + "\n</roblox>\n"
    )
    with open(OUT, "w", encoding="utf-8") as f:
        f.write(xml)
    print("Scritto %s (%d byte, %d oggetti)" % (OUT, len(xml.encode("utf-8")), _counter))


if __name__ == "__main__":
    sys.exit(main())

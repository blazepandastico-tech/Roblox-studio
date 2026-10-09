"""Aiuti per provare il file .rbxlx "cotto" nello shim Roblox (stessi strumenti di tools/preview)."""
import os
import subprocess

HERE = os.path.dirname(os.path.abspath(__file__))


def rbxbake_exe():
    exe = os.path.join(HERE, "rbxbake", "target", "release", "rbxbake")
    if not os.path.exists(exe):
        subprocess.check_call(["cargo", "build", "--release"], cwd=os.path.join(HERE, "rbxbake"))
    return exe


def dump_rbxlx(path):
    """Righe di record di quello che un lettore ufficiale e rigoroso (rbx_xml) trova dentro il file."""
    out = subprocess.run([rbxbake_exe(), "dump", path], check=True, capture_output=True, text=True).stdout
    return out.splitlines()


def import_baked(lua, rbxlx_path):
    """Carica nello shim (gia' inizializzato) workspace.World, Terrain e Lighting letti dal file. Restituisce (istanze, problemi)."""
    lua.globals().BAKED_LINES = lua.table_from(dump_rbxlx(rbxlx_path))
    lua.globals().IMPORT_LUA = os.path.join(HERE, "import_world.lua")
    res = lua.execute("local Imp = assert(loadfile(IMPORT_LUA))() local n, p = Imp.load(BAKED_LINES) return n, table.concat(p, '\\n')")
    return res[0], res[1]

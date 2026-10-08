#!/usr/bin/env python3
"""Esegue MapBuilder.Build() dentro lo shim Roblox (lupa) ed esporta la scena in JSON.
uso: run_map.py <src_dir> <out.json> [--call=Modulo.Funzione ...]"""
import sys, os, time
from lupa import LuaRuntime

here = os.path.dirname(os.path.abspath(__file__))
src = os.path.abspath(sys.argv[1])
out = os.path.abspath(sys.argv[2])
lua = LuaRuntime(unpack_returned_tuples=True)
lua.globals().API_INDEX_PATH = os.path.join(here, "api_index.lua")
t0 = time.time()
lua.execute(open(os.path.join(here, "robloxshim.lua"), encoding="utf-8").read())
files = []
for dp, dn, fn in os.walk(src):
    for f in fn:
        if f.endswith(".lua"):
            files.append(os.path.relpath(os.path.join(dp, f), src))
files.sort()
mount = lua.eval("function(root, list) local t = {} for i = 1, #list do t[i] = list[i] end __SHIM.mountFiles(root, t) end") if False else None
lua.execute("function __mount(root, ...) __SHIM.mountFiles(root, {...}) end")
lua.globals().__mount(src, *files)
driver = r'''
local Server = game:GetService("ServerScriptService"):WaitForChild("Server")
local MapBuilder = require(Server:WaitForChild("MapBuilder"))
local t = os.clock()
MapBuilder.Build()
local n, p = __SHIM.count()
return n, p, os.clock() - t
'''
n, p, dt = lua.execute(driver)
print("istanze: %d  parti: %d  (build %.2fs)" % (n, p, dt))
lua.execute('__SHIM.exportScene("%s")' % out)
rep = lua.execute(r"""
local S = __SHIM
local d = {}
for k in pairs(S.deprecated) do d[#d + 1] = k end
table.sort(d)
local st = {}
for k in pairs(S.stubs) do st[#st + 1] = k end
table.sort(st)
return table.concat(d, ", "), table.concat(st, ", "), table.concat(S.problems, "\n")
""")
dep, stubs, probs = rep
if dep: print("API deprecate usate:", dep)
if stubs: print("metodi non emulati (stub):", stubs)
if probs: print("PROBLEMI:", probs)
print("scritto", out, os.path.getsize(out) // 1024, "KB", "totale %.1fs" % (time.time() - t0))

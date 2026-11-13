"""Egg pack: EggConfig.luau, one EggPack.rbxmx with every egg, catalogue images and the mutation showcase.

``python -m studvox eggpack`` (after ``python -m studvox make models/eggs --hero-only``)
"""

from __future__ import annotations

import colorsys
import copy
import json
from pathlib import Path

from PIL import Image, ImageDraw

from . import roblox
from .eggs import BIOMES, MUTATIONS, RARITIES, RARITY
from .io import load_spec
from .palette import parse_hex, shade, to_hex
from .sheet import INK, card, chip, fit, font, paste_center, rgba, stud_paper, text

REPO = Path(__file__).resolve().parent.parent
EGG_SPECS = REPO / "models" / "eggs"
LUAU_EGGS = REPO / "roblox" / "eggs"


def collect(out_root: Path) -> list[dict]:
    eggs = []
    for spec in sorted(EGG_SPECS.rglob("*.py")):
        if spec.name.startswith("_"):
            continue
        model = load_spec(spec)
        data = model.to_dict()
        egg = dict(data["meta"]["egg"])
        lo, hi = data["bounds"]
        egg["model_height"] = round((hi[1] - lo[1] + 1) * data["voxel_size"], 2)
        egg["out"] = out_root / "eggs" / data["name"]
        egg["data"] = data
        egg["spec"] = spec
        eggs.append(egg)
    order = {b["id"]: i for i, b in enumerate(BIOMES)}
    eggs.sort(key=lambda e: (order[e["biome"]], e["rarity_index"]))
    return eggs


# ---------------------------------------------------------------------------- EggConfig.luau

CONFIG_FUNCS = r'''
EggConfig.RarityById = {}
for _, r in EggConfig.Rarities do
	r.color = Color3.fromHex(r.hex)
	EggConfig.RarityById[r.id] = r
end
EggConfig.BiomeById = {}
for _, b in EggConfig.Biomes do
	b.color = Color3.fromHex(b.hex)
	EggConfig.BiomeById[b.id] = b
end
EggConfig.MutationById = {}
for _, m in EggConfig.Mutations do
	EggConfig.MutationById[m.id] = m
end

local function pick(rng: Random?): number
	return if rng then rng:NextNumber() else math.random()
end

-- Rolls which egg spawns in a biome, using each egg's rarity spawn chance.
function EggConfig.RollEgg(biomeId: string, rng: Random?): string
	local biome = EggConfig.BiomeById[biomeId]
	assert(biome, `unknown biome {biomeId}`)
	local total = 0
	for _, id in biome.eggs do
		total += EggConfig.Eggs[id].spawnChance
	end
	local roll = pick(rng) * total
	for _, id in biome.eggs do
		roll -= EggConfig.Eggs[id].spawnChance
		if roll <= 0 then
			return id
		end
	end
	return biome.eggs[1]
end

-- Weight in kg: around the egg's base weight, sometimes a lot bigger.
function EggConfig.RollWeight(eggId: string, rng: Random?): number
	local egg = EggConfig.Eggs[eggId]
	local u1, u2 = math.max(pick(rng), 1e-6), pick(rng)
	local z = math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2)
	local w = egg.baseWeight * math.exp(z * EggConfig.WeightSpread)
	if pick(rng) < EggConfig.HugeChance then
		w *= 3 + pick(rng) * 3
	end
	return math.floor(math.max(w, egg.baseWeight * 0.3) * 10 + 0.5) / 10
end

function EggConfig.RollMutation(rng: Random?): string
	local roll = pick(rng) * 100
	for i = #EggConfig.Mutations, 1, -1 do
		local m = EggConfig.Mutations[i]
		if m.chance > 0 then
			if roll < m.chance then
				return m.id
			end
			roll -= m.chance
		end
	end
	return "normal"
end

-- Money per second once hatched: base income x size bonus x mutation multiplier.
function EggConfig.Income(eggId: string, weightKg: number, mutation: string?): number
	local egg = EggConfig.Eggs[eggId]
	local m = EggConfig.MutationById[mutation or "normal"] or EggConfig.MutationById.normal
	local size = (math.max(weightKg, 0.01) / egg.baseWeight) ^ 0.85
	return egg.baseIncome * size * m.multiplier
end

-- Heavier eggs take a bit longer to hatch.
function EggConfig.HatchSeconds(eggId: string, weightKg: number): number
	local egg = EggConfig.Eggs[eggId]
	local f = 0.75 + 0.25 * math.sqrt(math.max(weightKg, 0.01) / egg.baseWeight)
	return math.floor(egg.hatchSeconds * f + 0.5)
end

-- Model:ScaleTo() factor so an egg of this weight has a sensible in-game size.
function EggConfig.ScaleForWeight(eggId: string, weightKg: number): number
	local egg = EggConfig.Eggs[eggId]
	local rarity = EggConfig.RarityById[egg.rarity]
	local target = EggConfig.BaseEggHeight + EggConfig.HeightPerRarity * (rarity.index - 1)
	local grow = math.clamp((math.max(weightKg, 0.01) / egg.baseWeight) ^ (1 / 3), 0.6, 2.5)
	return target * grow / egg.modelHeight
end

-- WalkSpeed multiplier while carrying an egg of this weight.
function EggConfig.CarrySpeedMultiplier(weightKg: number): number
	return math.clamp(1 - 0.08 * math.log(1 + math.max(weightKg, 0)), 0.4, 1)
end

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx" }
function EggConfig.FormatMoney(n: number): string
	local i = 1
	while math.abs(n) >= 1000 and i < #SUFFIXES do
		n /= 1000
		i += 1
	end
	if i == 1 then
		return string.format("$%d", math.floor(n + 0.5))
	end
	local text = string.format("$%.1f%s", n, SUFFIXES[i])
	return (string.gsub(text, "%.0(%a)", "%1"))
end

return EggConfig
'''


def write_config(eggs: list[dict], path: Path) -> Path:
    rarities = [{"id": r["id"], "index": i + 1, "title": r["title"], "hex": r["color"], "fx": r["fx"],
                 "spawnChance": r["spawn"], "incomeMultiplier": r["income"]} for i, r in enumerate(RARITIES)]
    biomes = [{"id": b["id"], "index": i + 1, "title": b["title"], "hex": b["color"], "unlockSpeed": b["speed"],
               "eggs": [e["id"] for e in eggs if e["biome"] == b["id"]]} for i, b in enumerate(BIOMES)]
    muts = [{"id": m["id"], "title": m["title"], "multiplier": m["multiplier"], "chance": m["chance"],
             "look": m["look"]} for m in MUTATIONS]
    table = {}
    for e in eggs:
        table[e["id"]] = {"id": e["id"], "name": e["name"], "biome": e["biome"], "rarity": e["rarity"],
                          "spawnChance": e["spawn_chance"], "hatchSeconds": e["hatch_seconds"],
                          "baseIncome": e["base_income"], "baseWeight": e["base_weight"],
                          "unlockSpeed": e["unlock_speed"], "modelHeight": e["model_height"], "flavor": e["flavor"]}
    src = ["--!nonstrict",
           "-- StudVox egg collection: biomes, rarities, mutations and every egg's numbers.",
           "-- Generated by `python -m studvox eggpack` from models/eggs/**: edit the specs, not this file.",
           "",
           "local EggConfig = {}",
           "",
           "EggConfig.BaseEggHeight = 4.5 -- studs, a Common egg of normal weight",
           "EggConfig.HeightPerRarity = 0.45 -- extra studs per rarity tier",
           "EggConfig.WeightSpread = 0.35 -- log-normal spread of rolled weights",
           "EggConfig.HugeChance = 0.01 -- chance of a huge (3-6x) egg",
           "",
           "EggConfig.Rarities = " + roblox._lua(rarities),
           "",
           "EggConfig.Biomes = " + roblox._lua(biomes),
           "",
           "EggConfig.Mutations = " + roblox._lua(muts),
           "",
           "EggConfig.Eggs = " + roblox._lua(table),
           CONFIG_FUNCS]
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(src), encoding="utf-8")
    return path


# ---------------------------------------------------------------------------- EggPack.rbxmx

def _folder(w: roblox.XmlWriter, name: str):
    w.open("Folder", w.ref())
    w.string("Name", name)
    w.props_end()


def write_pack(eggs: list[dict], path: Path) -> Path:
    w = roblox.XmlWriter()
    animator = (roblox.LUAU_DIR / "StudVoxelAnimator.luau").read_text()
    _folder(w, "StudVoxEggs")
    _folder(w, "Eggs")
    for b in BIOMES:
        _folder(w, b["id"])
        for e in eggs:
            if e["biome"] == b["id"]:
                roblox.emit_model(w, roblox.plan(e["data"]), name=e["id"], animator_source=animator)
        w.close()
    w.close()
    roblox._script(w, "ModuleScript", "EggConfig", (LUAU_EGGS / "EggConfig.luau").read_text())
    roblox._script(w, "ModuleScript", "EggMutations", (LUAU_EGGS / "EggMutations.luau").read_text())
    roblox._script(w, "ModuleScript", "EggBillboard", (LUAU_EGGS / "EggBillboard.luau").read_text())
    roblox._script(w, "ModuleScript", "StudVoxelAnimator", animator)
    _folder(w, "Examples")
    roblox._script(w, "Script", "EggSpawner", (LUAU_EGGS / "EggSpawner.server.luau").read_text())
    roblox._script(w, "LocalScript", "EggClientEffects", (LUAU_EGGS / "EggClientEffects.client.luau").read_text())
    w.close()
    w.close()
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(w.text(), encoding="utf-8")
    return path


# ---------------------------------------------------------------------------- catalogue images

def _money(n: float) -> str:
    for suf in ("", "K", "M", "B", "T", "Qa", "Qi"):
        if abs(n) < 1000:
            return f"${n:,.0f}" if suf == "" else f"${n:.1f}{suf}".replace(".0", "")
        n /= 1000
    return f"${n:.1f}Sx"


def _speed(n: int) -> str:
    for suf in ("", "K", "M", "B", "T"):
        if abs(n) < 1000:
            return f"{n:g}{suf}"
        n /= 1000
    return f"{n:g}Q"


def _hero(e: dict) -> Image.Image | None:
    p = e["out"] / "renders" / "hero.png"
    return Image.open(p).convert("RGBA") if p.exists() else None


def _time(s: int) -> str:
    return f"{s}s" if s < 60 else (f"{s // 60}m" if s % 60 == 0 else f"{s // 60}m {s % 60}s")


def biome_sheet(b: dict, eggs: list[dict], path: Path) -> Path:
    W, H = 1800, 1060
    im = stud_paper(W, H)
    card(im, (30, 26, W - 30, 132), fill=rgba(b["color"]), radius=30, width=6)
    d = ImageDraw.Draw(im)
    text(d, (66, 79), b["title"].upper(), font("black", 58), fill=(255, 255, 255, 255), anchor="lm", stroke=7)
    tw = d.textlength(b["title"].upper(), font=font("black", 58)) + 14
    x = chip(im, (66 + tw + 24, 58), f"SPEED {_speed(b['speed'])}", rgba(shade(b["color"], -0.4)), font("black", 24))
    chip(im, (x + 12, 58), "10 EGGS", rgba("#1D1E22"), font("black", 24))
    d = ImageDraw.Draw(im)
    text(d, (W - 66, 79), "STUDVOX EGGS", font("black", 26), fill=(255, 255, 255, 235), anchor="rm", stroke=3)
    cw, chh, gap = 330, 432, 22
    for i, e in enumerate(eggs):
        cx = 30 + (i % 5) * (cw + gap) + 6
        cy = 160 + (i // 5) * (chh + gap)
        r = RARITY[e["rarity"]]
        card(im, (cx, cy, cx + cw, cy + chh), fill=(255, 255, 255, 255), radius=24, width=5)
        inner = Image.new("RGBA", (cw - 20, 268), rgba(shade(r["color"], 0.75)))
        m = Image.new("L", inner.size, 0)
        ImageDraw.Draw(m).rounded_rectangle((0, 0, inner.width - 1, inner.height - 1), 16, fill=255)
        im.paste(inner, (cx + 10, cy + 10), m)
        hero = _hero(e)
        if hero:
            paste_center(im, fit(hero, cw - 50, 250), (cx + 10, cy + 12, cx + cw - 10, cy + 276))
        d = ImageDraw.Draw(im)
        text(d, (cx + cw / 2, cy + 302), e["name"], font("black", 26), fill=INK, anchor="mm")
        rc = rgba(r["color"]) if e["rarity"] != "secret" else rgba("#2A2D36")
        lw = d.textlength(r["title"].upper(), font=font("black", 18)) + 28
        chip(im, (int(cx + cw / 2 - lw / 2), cy + 322), r["title"].upper(), rc, font("black", 18), pad=(14, 6))
        d = ImageDraw.Draw(im)
        text(d, (cx + cw / 2, cy + 378), f"{_money(e['base_income'])}/s  ·  {e['base_weight']:g} kg", font("bold", 21),
             fill=(40, 120, 40, 255), anchor="mm")
        text(d, (cx + cw / 2, cy + 406), f"spawn {e['spawn_chance']:g}%  ·  hatch {_time(e['hatch_seconds'])}",
             font("medium", 19), fill=(90, 90, 96, 255), anchor="mm")
    path.parent.mkdir(parents=True, exist_ok=True)
    im.convert("RGB").save(path, quality=88, optimize=True)
    return path


def full_catalogue(eggs: list[dict], path: Path) -> Path:
    T, gap, left, top = 150, 8, 250, 190
    W = left + 10 * (T + gap) + 30
    H = top + len(BIOMES) * (T + gap) + 40
    im = stud_paper(W, H)
    d = ImageDraw.Draw(im)
    text(d, (40, 64), f"STUDVOX EGGS · {len(eggs)}", font("black", 56), fill=(255, 255, 255, 255), anchor="lm", stroke=7)
    text(d, (40, 116), "14 biomes x 10 rarities · stud-style eggs for Roblox", font("bold", 24), fill=INK, anchor="lm")
    for i, r in enumerate(RARITIES):
        x = left + i * (T + gap)
        rc = rgba(r["color"]) if r["id"] != "secret" else rgba("#2A2D36")
        d.rounded_rectangle((x + 4, top - 44, x + T - 4, top - 12), 14, fill=rc, outline=INK, width=3)
        text(d, (x + T / 2, top - 28), r["title"].upper(), font("black", 15), fill=(255, 255, 255, 255), anchor="mm",
             stroke=2)
    for bi, b in enumerate(BIOMES):
        y = top + bi * (T + gap)
        d.rounded_rectangle((30, y + 6, left - 14, y + T - 6), 18, fill=rgba(b["color"]), outline=INK, width=4)
        lines = b["title"].upper().split(" ")
        for k, ln in enumerate(lines):
            text(d, ((30 + left - 14) / 2, y + T / 2 - 14 * (len(lines) - 1) + 28 * k), ln, font("black", 22),
                 fill=(255, 255, 255, 255), anchor="mm", stroke=3)
        for e in eggs:
            if e["biome"] != b["id"]:
                continue
            x = left + e["rarity_index"] * (T + gap)
            r = RARITY[e["rarity"]]
            d.rounded_rectangle((x, y, x + T, y + T), 16, fill=rgba(shade(r["color"], 0.78)), outline=INK, width=3)
            hero = _hero(e)
            if hero:
                paste_center(im, fit(hero, T - 18, T - 18), (x, y, x + T, y + T))
                d = ImageDraw.Draw(im)
    im.convert("RGB").save(path, quality=88, optimize=True)
    return path


# ---------------------------------------------------------------------------- mutation showcase

MUT_LOOKS = {
    "silver": ("#D7DEE6", 0.6, "metal"),
    "golden": ("#FFC42E", 0.65, "metal"),
    "diamond": ("#BEECFF", 0.7, "glass"),
}


def mutate(data: dict, mutation: str) -> dict:
    """Apply a mutation to a baked model (palette / voxel colours), for preview renders."""
    d = copy.deepcopy(data)
    d["name"] = f"{data['name']}_{mutation}"
    d["title"] = f"{mutation.title()} {data['title']}"
    if mutation in MUT_LOOKS:
        tint, amt, mat = MUT_LOOKS[mutation]
        tr, tg, tb = parse_hex(tint)
        for e in d["palette"]:
            if e["material"] == "glow":
                continue
            r, g, b = parse_hex(e["hex"])
            e["hex"] = to_hex((round(r + (tr - r) * amt), round(g + (tg - g) * amt), round(b + (tb - b) * amt)))
            e["material"] = mat
    elif mutation == "rainbow":
        n = 12
        base_len = len(d["palette"])
        for k in range(n):
            rr, gg, bb = colorsys.hsv_to_rgb(k / n, 0.7, 1.0)
            d["palette"].append({"name": f"rainbow{k}", "hex": to_hex((round(rr * 255), round(gg * 255), round(bb * 255))),
                                 "material": "plastic", "studs": True})
        for p in d["parts"]:
            for v in p["voxels"]:
                ci = v[3] & 0xFFF
                if ci < base_len and d["palette"][ci]["material"] == "glow":
                    continue
                k = int((v[1] * 0.8 + v[0] * 0.25) % n)
                v[3] = (base_len + k) | (v[3] & ~0xFFF)
    return d


def mutation_sheet(paths: dict[str, Path], egg_name: str, out: Path) -> Path:
    W, H = 1800, 620
    im = stud_paper(W, H)
    d = ImageDraw.Draw(im)
    text(d, (40, 60), "MUTATIONS", font("black", 54), fill=(255, 255, 255, 255), anchor="lm", stroke=7)
    tx = 40 + d.textlength("MUTATIONS", font=font("black", 54)) + 14 + 30
    text(d, (tx, 62), f"same egg ({egg_name}), five looks: applied at runtime by EggMutations.luau", font("bold", 24),
         fill=INK, anchor="lm")
    cw = (W - 80 - 4 * 20) / 5
    for i, m in enumerate(MUTATIONS):
        x = 40 + i * (cw + 20)
        card(im, (x, 110, x + cw, H - 40), fill=(255, 255, 255, 255), radius=24, width=5)
        p = paths.get(m["id"])
        if p and p.exists():
            paste_center(im, fit(Image.open(p).convert("RGBA"), int(cw - 40), 330), (x, 120, x + cw, 470))
        d = ImageDraw.Draw(im)
        text(d, (x + cw / 2, 500), m["title"].upper(), font("black", 30), fill=INK, anchor="mm")
        sub = f"x{m['multiplier']:g} income" + (f" · {m['chance']:g}%" if m["chance"] else "")
        text(d, (x + cw / 2, 538), sub, font("bold", 21), fill=(40, 120, 40, 255), anchor="mm")
    im.convert("RGB").save(out, quality=90, optimize=True)
    return out


def write_list(eggs: list[dict], path: Path) -> Path:
    """Markdown list (Italian) of every egg with its numbers."""
    lines = ["# Lista delle 140 uova", "",
             "Generata da `python -m studvox eggpack`. Rendita e peso sono i valori base: in gioco il peso",
             "viene tirato a caso allo spawn e la rendita cresce con il peso e la mutazione (vedi `EggConfig.Income`).",
             ""]
    for b in BIOMES:
        group = [e for e in eggs if e["biome"] == b["id"]]
        lines += [f"## {b['title']} · velocità {_speed(b['speed'])}", "", f"![{b['title']}]({b['id']}.jpg)", "",
                  "| Uovo | Rarità | Rendita base | Peso base | Spawn | Schiusa | Spec |", "|---|---|---|---|---|---|---|"]
        for e in group:
            rel = e["spec"].relative_to(REPO)
            lines.append(f"| {e['name']} | {e['rarity_title']} | {_money(e['base_income'])}/s | {e['base_weight']:g} kg | "
                         f"{e['spawn_chance']:g}% | {_time(e['hatch_seconds'])} | [{e['id']}.py](../../{rel}) |")
        lines.append("")
    path.write_text("\n".join(lines), encoding="utf-8")
    return path


def build(out_root: Path, *, images: bool = True, showcase: str | None = "galaxy_egg", blender=None) -> list[Path]:
    eggs = collect(out_root)
    written = [write_config(eggs, LUAU_EGGS / "EggConfig.luau")]
    written.append(write_pack(eggs, out_root / "eggs" / "EggPack.rbxmx"))
    docs = REPO / "docs" / "eggs"
    if images:
        for b in BIOMES:
            group = [e for e in eggs if e["biome"] == b["id"]]
            written.append(biome_sheet(b, group, docs / f"{b['id']}.jpg"))
        written.append(full_catalogue(eggs, docs / "catalog.jpg"))
        written.append(write_list(eggs, docs / "LISTA_UOVA.md"))
    if showcase and blender:
        import subprocess
        from .io import save
        egg = next((e for e in eggs if e["id"] == showcase), eggs[0])
        paths = {"normal": egg["out"] / "renders" / "hero.png"}
        for m in MUTATIONS[1:]:
            md = mutate(egg["data"], m["id"])
            od = out_root / "eggs_mutations" / md["name"]
            od.mkdir(parents=True, exist_ok=True)
            sv = save(md, od / f"{md['name']}.svox.json")
            subprocess.run(blender + ["--model", str(sv), "--out", str(od), "--render", "--hero-only", "--size", "640",
                                      "--samples", "28"], capture_output=True, text=True, check=True)
            paths[m["id"]] = od / "renders" / "hero.png"
        written.append(mutation_sheet(paths, egg["name"], docs / "mutations.jpg"))
    summary = {e["id"]: {k: e[k] for k in ("name", "biome", "rarity", "base_income", "base_weight", "hatch_seconds",
                                           "spawn_chance")} for e in eggs}
    (docs / "eggs.json").parent.mkdir(parents=True, exist_ok=True)
    (docs / "eggs.json").write_text(json.dumps(summary, indent=1))
    written.append(docs / "eggs.json")
    return written

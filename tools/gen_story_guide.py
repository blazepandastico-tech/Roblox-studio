#!/usr/bin/env python3
"""Genera docs/GUIDA_STORIA.md leggendo src/shared/Data/Story.lua.

Uso: python3 tools/gen_story_guide.py
Rilancialo ogni volta che cambi la storia, così la guida resta identica al gioco.
"""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
STORY = ROOT / "src/shared/Data/Story.lua"
OUT = ROOT / "docs/GUIDA_STORIA.md"
# copia dentro il gioco: ServerStorage > LEGGIMI_GuidaStoria (si apre con doppio clic in Studio)
STUDIO = ROOT / "studio/LEGGIMI_GuidaStoria.lua"

SEASONS = {
    1: "Stagione 1 - isola di Vermiglia",
    2: "Stagione 2 - isola di Edenia",
    3: "Stagione 3 - isole di Aurea e Cenere",
    4: "Stagione 4 - continente di Valdoria",
}
KIND = {
    "Cutscene": "🎬 Filmato",
    "Talk": "💬 Parla (tasto F)",
    "Reach": "📍 Raggiungi",
    "Kill": "⚔️ Uccidi",
    "Enemy": "🗡️ Sconfiggi",
    "Boss": "👹 BOSS",
    "HumanBoss": "👹 BOSS",
    "Level": "⬆️ Livello",
    "Collect": "📦 Raccogli",
}


def main():
    text = STORY.read_text(encoding="utf-8")
    start = text.index("Story.Chapters = {")
    body = text[start:]
    chapters = []
    for m in re.finditer(r'Id = "(S(\d)C\d)",', body):
        chapters.append((m.start(), m.group(1), int(m.group(2))))
    lines = [
        "# Guida alla storia di Sieri Perduti",
        "",
        "Generata automaticamente da `src/shared/Data/Story.lua` (`python3 tools/gen_story_guide.py`).",
        "",
        "Il prossimo obiettivo compare sempre come notifica **Nuovo obiettivo**, nel riquadro a destra",
        "dello schermo e in **Menu (M) → Storia**. Con i personaggi si parla con **F**.",
        "",
        "## Comandi di prova (solo in Roblox Studio o per il proprietario del gioco)",
        "",
        "| Comando | Cosa fa |",
        "|---|---|",
        "| `/aiuto` | elenco dei comandi |",
        "| `/capitolo N` | salta all'inizio del capitolo N (1-17) |",
        "| `/passo` | completa l'obiettivo attuale |",
        "| `/livello N` | porta il personaggio al livello N |",
        "| `/oro N`, `/gemme N` | aggiunge oro o gemme |",
        "| `/vai Zona` | teletrasporto (es. `/vai Recinto`, `/vai Aurion`, `/vai Halvar`) |",
        "| `/zone` | elenco delle zone |",
        "| `/cura` | vita, gas e lame al massimo |",
        "| `/tutorial` | rifà l'Addestramento di base da capo (come un giocatore nuovo) |",
        "",
        "Per verificare un capitolo: `/livello` al livello richiesto, `/capitolo N`, poi segui gli obiettivi",
        "(oppure `/passo` per saltarli uno alla volta).",
        "",
    ]
    season = 0
    for i, (pos, cid, s) in enumerate(chapters):
        end = chapters[i + 1][0] if i + 1 < len(chapters) else len(body)
        block = body[pos:end]
        title = re.search(r'Title = "([^"]+)"', block).group(1)
        level = re.search(r"Level = (\d+),", block).group(1)
        summary = re.search(r'Summary = "([^"]+)"', block)
        if s != season:
            season = s
            lines += [f"## {SEASONS.get(s, f'Stagione {s}')}", ""]
        lines.append(f"### {i + 1}. {title} (livello {level}) — `/capitolo {i + 1}`")
        if summary:
            lines += ["", f"_{summary.group(1)}_"]
        lines.append("")
        steps = re.split(r"\n\t\t\t\{", block)
        n = 0
        for step in steps[1:]:
            t = re.search(r'Type = "(\w+)"', step)
            o = re.search(r'Objective = "([^"]+)"', step)
            if not t or not o:
                continue
            n += 1
            lines.append(f"{n}. {KIND.get(t.group(1), t.group(1))}: {o.group(1)}")
            # il tutorial (Data/Tutorial.lua) si fa dopo il prologo, prima di Brehm
            if i == 0 and n == 1:
                lines.append(
                    "   - 🎓 **Missione 0 - Addestramento di base** (tutorial, con Mira): comandi passo per passo,"
                    " le isole sulla mappa, l'interfaccia e i giganti. Si rivede da Menu (M) → Opzioni."
                )
        lines.append("")
    lines += [
        "Alla fine del capitolo 17 compare **STORIA COMPLETATA**. I Sieri Perduti (gli 8 giganti",
        "mutaforma) arriveranno con il prossimo aggiornamento.",
        "",
    ]
    OUT.write_text("\n".join(lines), encoding="utf-8")
    STUDIO.parent.mkdir(exist_ok=True)
    guide = "\n".join(lines).replace("]==]", "] ==]")
    STUDIO.write_text(
        "--[==[\n" + guide + "\n]==]\n\n-- Questo script contiene solo la guida: non fa nulla nel gioco.\nreturn {}\n",
        encoding="utf-8",
    )
    print(f"Scritto {OUT.relative_to(ROOT)}: {len(chapters)} capitoli")


if __name__ == "__main__":
    main()

# Guida al lancio di Sieri Perduti

Cosa fare **prima di pubblicare** e **come far crescere il gioco** dopo il lancio.
Nessuno può garantire che un gioco diventi virale, ma questi sono i passi che fanno la differenza.

---

## 1. Prova completa in Studio (30 minuti, da fare per primo)

Apri `SieriPerduti.rbxlx` → **Play**. Controlla in quest'ordine:

| # | Cosa provare | Cosa deve succedere |
|---|---|---|
| 1 | Ingresso | Filmato iniziale, poi l'**Addestramento di base** con Mira (comandi, anelli d'oro, sagoma, mappa animata, interfaccia, giganti); alla fine la telecamera vola da Brehm e si apre il **Calendario dei premi** (Giorno 1). Per rifarlo: `/tutorial` |
| 2 | Movimento | Camminata/corsa da battaglia, **Shift** = shift lock, salto e **caduta** con le braccia che si agitano |
| 3 | Obiettivo | Colonna di luce dorata + "◆ xx m" sull'obiettivo; parla con Brehm (**F**) |
| 4 | Rampini | **Q / E** per agganciarti, sali in cima alla torre |
| 5 | Combattimento | Sagome e giganti: colpisci la **nuca** (clic sinistro) |
| 6 | Pulsanti a sinistra | 🎁 Premi (calendario, regali a tempo, ruota), 🏆 Classifiche, 👥 Invita |
| 7 | Ruota | Scrivi `/giri 5` in chat, apri 🎁 → Ruota → GIRA |
| 8 | Menu (M) | Schede Traguardi e Classifiche |
| 9 | Negozio (N) | Gemme, monete, pass (in Studio gli acquisti sono simulati gratis) |
| 10 | Storia | `/livello 200` poi `/capitolo 6` → traghettatore per Edenia |
| 11 | Mura | Vola fino alle mura di Vermiglia: torri, cannoni, porte con stendardi |

Se qualcosa non va: copia l'**Output** (Visualizza → Output) e mandalo.

## 2. Pubblicare

1. **File → Pubblica su Roblox** (nuovo gioco).
2. **Impostazioni del gioco → Sicurezza**: attiva *Enable Studio Access to API Services* (salvataggi e classifiche).
3. **Impostazioni del gioco → Avatar**: tipo di avatar **R15** (le animazioni funzionano solo con R15).
4. Su **create.roblox.com → il tuo gioco**:
   - compila il **questionario sui contenuti** (combattimento con armi bianche, giganti che afferrano i giocatori);
   - imposta il gioco **Pubblico** quando sei pronto.

## 3. Attivare i guadagni (senza questo il negozio mostra "In arrivo")

Su create.roblox.com → il tuo gioco → **Monetizzazione**:

1. **Passes**: crea Oro Doppio (349), Esperienza Doppia (399), Bombole Rinforzate (199),
   Fortuna del Cacciatore (449), Viaggiatore (249), VIP dell'Arcipelago (499).
2. **Developer Products**: crea i pacchetti di gemme (49 / 249 / 499 / 999 / 2499), di monete
   (49 / 249 / 799), i giri della ruota (79 / 229) e il **Pacchetto della Recluta** (99).
3. Copia ogni ID numerico in `src/shared/Data/Monetization.lua` (campi `ProductId` / `PassId`),
   oppure in Studio dentro `ReplicatedStorage → Shared → Data → Monetization`.
4. **Server privati**: nelle impostazioni del gioco attivali a pagamento (es. 100 Robux al mese):
   nei giochi a raid sono molto richiesti.

## 4. Medaglie e gruppo (portano giocatori nuovi)

- **Medaglie**: create.roblox.com → Medaglie → crea le medaglie dei traguardi principali
  (Benvenuto, Primo Sangue, Ammazzaboss, Livello 200, Stagione 1...). Copia gli ID in
  `src/shared/Data/Achievements.lua` (campo `BadgeId`). Le medaglie compaiono sul profilo dei giocatori
  e i loro amici le vedono.
- **Gruppo Roblox**: crea un gruppo (es. "Sieri Perduti Studio"), metti l'ID in `Config.lua → GroupId`.
  Chi entra riceve 50 gemme, 2 giri e +10% oro per sempre: il gruppo ti permette poi di avvisare
  tutti i giocatori a ogni aggiornamento.

## 5. Pagina del gioco

- **Nome**: corto e chiaro, ad esempio *"⚔️ Sieri Perduti: Giganti [NUOVO]"*.
  **Non** usare nomi o loghi di opere famose nel titolo, nelle immagini o nei tag.
- **Icona**: un personaggio con le lame davanti a un gigante enorme, colori forti, poco testo.
- **Miniature**: 3–5 immagini d'azione prese dal gioco (volo con i rampini, colpo alla nuca, raid, mura).
- **Descrizione** (esempio):

> Diventa una recluta del Corpo dei Falchi! Vola con i rampini a gas, abbatti giganti colpendoli
> alla nuca, sali di livello fino al 2000 ed esplora un arcipelago di isole.
> ⚔️ Storia in 4 stagioni • 🔱 Raid con gli amici • 🎡 Ruota della Fortuna • 🏆 Classifiche globali
> 🎁 CODICI: SIERIPERDUTI, ARCIPELAGO, BENVENUTORECLUTA
> 👍 Metti mi piace e ⭐ preferito per nuovi codici a ogni aggiornamento!

## 6. Far crescere il gioco

1. **Video brevi** (TikTok, YouTube Shorts, Reels): 15–30 secondi d'azione pura. Un colpo alla nuca
   al rallentatore, un raid con un boss enorme, una caduta spettacolare dalle mura. Pubblicane uno al giorno
   nelle prime settimane.
2. **Codici legati ai like**: "1.000 like = nuovo codice". Aggiungili in `CodesService.lua`.
3. **Aggiornamenti regolari**, anche piccoli, ogni 1–2 settimane: Roblox premia i giochi aggiornati.
   Scrivi la data nel titolo: *"[AGG 2] Sieri Perduti"*.
4. **Eventi nel fine settimana**: esperienza doppia (`Config.lua → XPMultiplier = 2`) annunciata nel gruppo.
5. **Annunci su Roblox** (Ads Manager): parti con un budget piccolo e una miniatura chiara.
6. **Discord**: un server per la community, dove chiedere idee e segnalare bug.

## 7. Prossimi aggiornamenti consigliati

| Aggiornamento | Contenuto |
|---|---|
| **AGG 2** | Gli 8 giganti mutaforma: in `Config.lua → Serums.Available = true` |
| AGG 3 | Nuova isola e nuovo raid, nuove lame leggendarie |
| AGG 4 | Il Gigante Fondatore (come gran finale) e una nuova stagione della storia |

## 8. Numeri da guardare (create.roblox.com → Analisi)

- **Ritorno dopo 1 giorno (D1)**: sopra il 20% è buono. Se è basso, rendi più facili i primi 10 minuti.
- **Durata media della sessione**: oltre 15 minuti è buono (aiutano i regali a tempo).
- **Conversione** (quanti comprano): guarda quali pass si vendono di più e mettili in evidenza.

## Nota importante sul copyright

Nomi, isole, storia, stemmi e personaggi sono originali. I **modelli dei giganti puri** però sono stati
fatti copiando l'aspetto dei giganti di un'immagine dell'anime, come hai chiesto: questo può portare a
segnalazioni per diritto d'autore. Per stare tranquillo, prima o poi modificali
(`src/shared/Anim/TitanBuilder.lua`) e non usarli mai nelle immagini della pagina insieme a riferimenti all'anime.

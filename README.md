# Sieri Perduti: L'Arcipelago dei Giganti

Un MMO d'azione per Roblox: cadetti armati di lame e **rampini a gas** che volano tra i tetti e
abbattono giganti colpendoli alla nuca, in un arcipelago di isole da esplorare livello dopo livello
(stile "mari" dei grandi MMO di Roblox). Storia originale in 4 stagioni, missioni ripetibili, boss,
raid a ondate, negozio premium e — dal prossimo aggiornamento — gli 8 poteri dei giganti mutaforma.

Tutti i nomi, i luoghi, gli stemmi e la storia sono **originali** (nessun nome o simbolo di opere protette).

---

## 1. Aprire il gioco in Roblox Studio

**Modo semplice:** scarica `SieriPerduti.rbxlx` da questo repository, poi in Roblox Studio
**File → Apri da file** e premi **Play** (▶️). La mappa viene costruita dal server in pochi secondi.

**Per salvare i progressi dei giocatori anche in Studio:**
1. **File → Pubblica su Roblox** (dai un nome al gioco).
2. **Home → Impostazioni del gioco → Sicurezza → "Enable Studio Access to API Services"** = attivo.

**Per vedere/modificare la mappa senza premere Play:** apri la *Command Bar* (Visualizza → Command Bar) e scrivi
```lua
require(game.ServerScriptService.Server.Services.WorldBuilder).Build()
```
poi salva il luogo: all'avvio il server non rigenera una mappa che esiste già.

**Per sviluppatori (Rojo):** il codice è in `src/` ed è un progetto [Rojo 7](https://rojo.space).
`rojo serve` + plugin Rojo in Studio per sincronizzare, oppure `rojo build default.project.json -o SieriPerduti.rbxlx`.

## 2. Comandi

| PC | Azione |
|---|---|
| **Q / E** (tieni premuto) | rampino sinistro / destro |
| **Spazio** | salto, getto di gas in volo |
| **W A S D** in volo | sterzare attorno ai rampini |
| **Shift** | schivata |
| **Ctrl sinistro** | alterna camminata tattica / corsa d'assalto |
| **Clic sinistro** | fendente (combo da 4 colpi) — mira alla **nuca**! |
| **Clic destro** | arma a distanza (lance dirompenti, pistole, fucili...) |
| **Z X C V** | abilità delle lame |
| **R** | sostituisci le lame |
| **F** | parla con i personaggi, usa, raccogli |
| **M** | menu (equipaggiamento, statistiche, sieri, storia, codici, impostazioni) |
| **N** | negozio premium |
| **T** | trasformazione in gigante (prossimo aggiornamento) |
| **G** | Risveglio della stirpe Valkar |
| **Alt sinistro** | sblocca il cursore |

Su telefono e tablet compaiono pulsanti a schermo.

## 3. Il mondo: l'arcipelago

Ci si sposta tra le isole con i **traghettatori** (uno in ogni città principale) o con le navi.

| Isola | Stagione | Livello | Cosa c'è |
|---|---|---|---|
| **Vermiglia** | 1 | 1+ | Campo di Addestramento, Quartier Generale, Muro Vermiglio, Distretto di Calaneth, Pianure, Foresta dei giganti, Porto Orientale |
| **Edenia** | 2 | 200+ | Villaggio di Brenn, Castello di Ostrava, Gola di Edenia |
| **Aurea** | 3 | 450+ | la capitale **Aurion** dentro il Muro Aureo, Stohlberg, la Città Sotterranea, la Caverna di Cristallo |
| **Cenere** | 3 | 800+ | la patria perduta: Muro di Cenere in rovina, Rovine di Halvar, il seminterrato |
| **Valdoria** | 4 | 1000+ | il continente oltre il mare: porto, trincee, Revelia, la fortezza di Vael, il Fronte della Grande Marcia |
| **Arena** | Raid | 120+ | l'anfiteatro dove si combattono i raid |

## 4. Giganti, boss e raid

- **Giganti normali** (da 3 a 15 metri, più gli anomali) popolano ogni isola: più ti allontani, più sono forti.
  Si uccidono colpendo la **nuca**; si possono anche tagliare braccia e gambe o accecarli.
- **Boss**: Ghignante, Cacciatrice, Fauno, Bastione, Zanna, Strisciante, Vulcano, Destriero, Forgia, Furia e il Primordiale.
- **Raid** (dai Maestri dei Raid al Quartier Generale, ad Aurion e a Revelia): chi avvia il raid paga
  l'oro (o un *Sigillo del Raid*), gli altri si uniscono gratis entro 30 secondi. Ondate di giganti e un
  boss finale nell'Arena. Ricompense: oro, esperienza, **gemme**, Frammenti di Siero e bottino.
  5 raid: Assalto al Recinto (Lv.120), La Caccia nella Foresta (300), Le Mura di Pietra (550),
  Il Risveglio del Vulcano (900), La Grande Marcia (1500).

## 5. Gli 8 Giganti Mutaforma (prossimo aggiornamento)

I Sieri Perduti danno il potere di trasformarsi in uno degli **otto giganti**: Furia, Bastione, Vulcano,
Cacciatrice, Fauno, Zanna, Destriero e Forgia (4 abilità ciascuno e una maestria da far crescere).
**Per ora non si possono ottenere**: nel menu "Sieri" si vede l'anteprima con il lucchetto.
I giocatori possono già raccogliere i **Frammenti di Siero** che serviranno per sintetizzarli.

Per attivarli nel prossimo aggiornamento basta una riga in `src/shared/Config.lua`:
```lua
Serums = {
	Available = true, -- era false
```
Quando sono attivi si ottengono (con enorme fatica) da casse rarissime nel mondo, drop dei boss,
il Mercante Velato ad Aurion e il Laboratorio (centinaia di frammenti).

## 6. Negozio premium (gemme, monete, game pass)

Tasto **N** o pulsante 💎. Contiene:
- **Gemme** (valuta premium) e **Monete d'oro** con Robux;
- **Game Pass**: Oro Doppio, Esperienza Doppia, Bombole Rinforzate, Fortuna del Cacciatore, Viaggiatore (viaggio rapido), VIP dell'Arcipelago (nome dorato, [VIP] in chat, mantello, gemme giornaliere);
- **Negozio delle Gemme**: Sigilli del Raid, pozioni dell'oro, pergamene dell'esperienza, adrenalina, cambio stirpe, azzera statistiche, mantelli cosmetici.

Le gemme si guadagnano anche giocando (accesso giornaliero, primo boss di ogni tipo, raid, codici).

**Per vendere davvero con Robux** (solo dopo aver pubblicato il gioco):
1. create.roblox.com → il tuo gioco → **Monetizzazione** → crea i *Developer Products* e i *Passes* con gli stessi prezzi;
2. copia gli ID numerici in `src/shared/Data/Monetization.lua` (campi `ProductId` e `PassId`).

Finché un ID vale `0`, **in Studio l'acquisto viene simulato gratis** (per provarlo), mentre nel gioco
pubblicato quella voce risulta "non disponibile". Gli acquisti sono gestiti in modo sicuro
(`ProcessReceipt` con registro delle ricevute e salvataggio prima della conferma).

## 7. Codici regalo

`SIERIPERDUTI`, `ARCIPELAGO`, `CORPODEIFALCHI`, `BENVENUTORECLUTA`, `OLTREILMARE`, `PRIMORAID`
(Menu → Codici). Aggiungine altri in `src/server/Services/CodesService.lua`.

## 8. Personalizzare

| Cosa | Dove |
|---|---|
| Nome del gioco, velocità, difficoltà, sieri attivi | `src/shared/Config.lua` |
| Armi, rampini, uniformi, accessori | `src/shared/Data/Items.lua` |
| Isole e posizioni | `src/shared/Data/WorldLayout.lua`, `Zones.lua` |
| Storia e dialoghi | `src/shared/Data/Story.lua`, `NPCs.lua` |
| Missioni, raid | `Quests.lua`, `Raids.lua` |
| Prezzi in Robux e negozio delle gemme | `Monetization.lua` |
| Suoni e musica (ID del Creator Store) | `Sounds.lua` |
| Animazioni caricate da te (opzionale) | `AnimationIds.lua` |

Le animazioni sono **procedurali** (calcolate dal codice): funzionano subito senza caricare nulla.

## 9. Controlli automatici (per sviluppatori)

```bash
python3 tools/check_refs.py   # riferimenti tra servizi, remote e require
python3 tools/test_data.py    # coerenza di storia, missioni, isole, raid, negozi (serve 'luau')
```

Vedi `docs/DESIGN.md` per l'architettura del codice.

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
| **Shift** | attiva/disattiva lo shift lock (senza: mouse libero, mira col cursore) |
| **Ctrl sinistro** | schivata |
| **Bloc Maiusc** | alterna camminata tattica / corsa d'assalto |
| **Clic sinistro** | fendente (combo da 4 colpi) — mira alla **nuca**! |
| **Clic destro** | arma a distanza (lance dirompenti, pistole, fucili...) |
| **Z X C V** | abilità delle lame |
| **R** | sostituisci le lame |
| **F** | parla con i personaggi, usa, raccogli |
| **M** | menu (equipaggiamento, statistiche, sieri, storia, codici, impostazioni) |
| **B** | mappa dell'arcipelago (rotella = zoom, trascina, clic destro = segnaposto) |
| **H** | chiama il cavallo / scendi |
| **W A S D** in barca | velocità e timone (Spazio per scendere) |
| **N** | negozio premium |
| **T** | trasformazione in gigante (per ora solo per gli admin) |
| **P** | Pannello Admin (solo amministratori) |
| **G** | Risveglio della stirpe Valkar |
| **Alt sinistro** | sblocca il cursore |

Su telefono e tablet compaiono pulsanti a schermo.

### Volo con i rampini: consigli
- Un aggancio **vicino** tira più forte di uno al limite della portata; tirare **nella direzione in cui voli**
  rende di più che tirare all'indietro (per invertire la rotta conviene oscillare attorno al cavo).
- **Slancio cinetico**: volando veloce rasente a muri, alberi e tetti accumuli slancio, fino a +35% di velocità massima.
- Le **Lance Dirompenti** si conficcano nel bersaglio: la miccia lampeggia per 1,4 secondi e poi esplodono.
- Le lame si consumano a ogni colpo, e molto di più sulle **corazze**: tieni d'occhio la durabilità (R per sostituirle).

## 3. Il mondo: l'arcipelago (mondo aperto)

Il mondo è **aperto**: nessuna isola è bloccata. Ci si sposta con la **propria barca** (si prende ai
pontili con **F**, o chiedendola al traghettatore), a nuoto, oppure con i **traghettatori** (viaggio veloce).
Se vai in un'isola troppo forte per te, il gioco ti avvisa, ma non ti ferma.

| Isola | Stagione | Livello | Cosa c'è |
|---|---|---|---|
| **Vermiglia** | 1 | 1+ | Campo di Addestramento, Quartier Generale, Muro Vermiglio, Distretto di Calaneth, Pianure, Foresta dei giganti, Porto Orientale |
| **Edenia** | 2 | 200+ | Villaggio di Brenn, Castello di Ostrava, Gola di Edenia |
| **Aurea** | 3 | 450+ | la capitale **Aurion** dentro il Muro Aureo, Stohlberg, la Città Sotterranea, la Caverna di Cristallo |
| **Cenere** | 3 | 800+ | la patria perduta: Muro di Cenere in rovina, Rovine di Halvar, il seminterrato |
| **Valdoria** | 4 | 1000+ | il continente oltre il mare: porto, trincee, Revelia, la fortezza di Vael, il Fronte della Grande Marcia |
| **Arena** | Raid | 120+ | l'anfiteatro dove si combattono i raid |

### Il mare aperto e gli isolotti

| Isolotto | Livello | Cosa c'è |
|---|---|---|
| Isola dei Gabbiani | 150-220 | scogli, giganti da 7 e 10 metri |
| Isola del Faro | 250-350 | il faro (dalla cima si vede tutto), la casa del guardiano |
| Banco di Sabbia | 300-400 | una lingua di sabbia con tronchi e giganti |
| Scogli dei Naufraghi | 400-500 | il relitto di una nave mercantile |
| Torre Sommersa | 600-700 | una torre antica mezza sommersa |
| Rifugio dei Contrabbandieri | 850-950 | palizzata, capanne e contrabbandieri armati |
| Scoglio di Brace | 1250-1400 | un vulcano spento che fuma, giganti feroci |
| Isola delle Palme | zona sicura | palme, falò e il mercante Ezio |

- **Eventi in mare**: ogni pochi minuti, vicino a chi naviga, **emerge un gigante dalle onde** oppure compare
  un **relitto alla deriva** con un carico da saccheggiare (oro, gemme, bombole). Si vedono sulla mappa.
- **Mappa e minimappa**: la minimappa è in alto a sinistra; la mappa grande (**B**) colora le zone in base al
  tuo livello (verde sicura, giallo giusta per te, arancione/rosso pericolosa) e mostra porti, negozi, taverne.
- **42 forzieri nascosti** (comuni, rari, leggendari) sopra mura, torri, tetti, alberi giganti, nelle grotte,
  nelle taverne e sugli isolotti. Ogni 10 trovati: +30 💎; tutti: +100 💎 e traguardi. Gli osti nelle
  **taverne** raccontano le voci su dove cercarli.
- **Taverne** (Calaneth, Brenn, Aurion, Porto Orientale, Porto di Revelia): ci si entra, si parla con l'oste,
  si mangia un pasto caldo (salute, gas e lame al massimo, +10% danni per 10 minuti).
  Anche molte case delle città e le baracche del campo hanno l'interno visitabile.
- **Cavallo** (**H**): veloce sulle pianure; si scende da soli usando i rampini, attaccando o entrando in acqua.
- **PvP**: si attiva da **Menu → Opzioni** (o dal Maestro dei Duelli). Funziona solo fuori dalle zone sicure e con
  chi l'ha attivo; nell'**Arena dei Duelli** (fuori dalla porta nord di Vermiglia) è sempre attivo.
  Chi vince guadagna una **taglia** 💰 (e ruba il 10% di quella dello sconfitto), visibile sopra la testa e in classifica.

## 3b. Un mondo vivo: cielo, meteo, natura, città e musica

- **Cielo e luce**: alba rosata, tramonto arancione, notte blu con le stelle, raggi di sole e nebbia che
  cambiano con l'ora e con la zona (foresta verde, cenere di Halvar, cielo rosso al Fronte...).
- **Meteo** (uguale per tutti i giocatori del server, cambia da solo ogni 3-13 minuti): *Sereno*,
  *Nuvoloso*, *Pioggia* (gocce e schizzi a terra) e *Temporale* (lampi, tuoni, vento forte).
  Il vento piega l'erba, fa ondeggiare gli alberi e sposta il fumo. Dal pannello admin (**P → Mondo → Meteo**)
  si sceglie il meteo all'istante, utile per provarlo.
- **Natura**: erba 3D che si muove col vento sui prati, chiome degli alberi che ondeggiano, macchie di fiori
  colorati, stormi di uccelli di giorno, farfalle col sereno e lucciole di notte.
- **Città vive**: cittadini che passeggiano per le strade (meno di notte), banchi del mercato con i tendoni
  a strisce, carretti, festoni colorati sopra il viale e fumo che esce dai camini. Le città in rovina restano deserte.
- **Musica dinamica**: cambia da sola con una dissolvenza tra *calma* (giorno), *città*, *notte*, *battaglia*
  (giganti vicini o che ti inseguono) e *boss/raid*, più i suoni d'ambiente (pioggia, vento, uccellini, grilli).
  **Le tracce vanno scelte da te**: apri `src/shared/Data/Sounds.lua` (in Studio: ReplicatedStorage → Shared →
  Data → Sounds), cerca le tracce nella Casella degli strumenti → Audio, copia l'ID e incollalo come
  `"rbxassetid://123..."`. Una situazione lasciata vuota usa la traccia `Default`.

Tutti questi dettagli sono solo grafici (ogni giocatore li vede sul suo dispositivo) e si adattano alla qualità
grafica. Chi ha un dispositivo lento può spegnerli: **Menu (M) → Impostazioni → Dettagli ambientali**.

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

## 6b. Premi, classifiche e community

- **🎁 Premi** (pulsante a sinistra): calendario di 7 giorni di fila, regali a tempo (più giochi oggi,
  più regali apri) e **Ruota della Fortuna** (un giro gratis ogni 20 ore, probabilità sempre visibili;
  i giri a pagamento non compaiono nei paesi dove sono vietati).
- **🏆 Classifiche globali** (Menu → Classifiche e tabelloni al Campo di Addestramento): livello,
  giganti uccisi, raid vinti.
- **🏅 Traguardi** (Menu → Traguardi): 24 obiettivi che regalano gemme e, se configuri le medaglie, i badge Roblox.
- **👥 Amici**: +10% esperienza per ogni amico nello stesso server (fino a +30%) e pulsante Invita.
- **⭐ Gruppo**: con `Config.GroupId` chi entra nel gruppo riceve un regalo e +10% oro per sempre.
- **Pacchetto della Recluta**: offerta per i nuovi giocatori (solo i primi 3 giorni, una volta sola).
- **Segnalino dell'obiettivo**: colonna di luce e distanza verso il prossimo obiettivo della storia.

Tutti i passi per pubblicare e far crescere il gioco sono in [`docs/LANCIO.md`](docs/LANCIO.md).
Icona, miniature e descrizione per la pagina del gioco: [`docs/PAGINA_ROBLOX.md`](docs/PAGINA_ROBLOX.md) (immagini in `assets/pagina_roblox/`).
Evento di lancio **🎉 Grande Inaugurazione** (2x XP e oro, Colosso d'Oro, fuochi d'artificio, 8 sfide): [`docs/EVENTO_INAUGURAZIONE.md`](docs/EVENTO_INAUGURAZIONE.md), con trailer e locandine in `assets/evento/`.

## 6c. Il Gigante della Furia con modello 3D (es. da Meshy)

Il **Gigante della Furia** (il gigante di Tobias) usa un modello 3D vero: come boss della Fortezza di Vael,
nei filmati della storia e quando un giocatore usa il **Siero della Furia**, che è il **primo siero**
(Pannello Admin → Sieri). In forma di gigante cammina e corre con passi pesanti e ha mosse dedicate:
clic sinistro = ganci destro/sinistro, **Z** Pugno Indurito (pugno di cristallo), **X** Calcio Rotante
(colpisce tutto intorno), **C** Ruggito della Furia (stordisce), **V** Visione del Futuro (invulnerabile + danni).
Il file pronto da importare è `assets/modelli/GiganteFuria.glb`: è già diviso in 15 parti del corpo,
con i punti delle articolazioni e le texture incluse.

1. In Studio: **File → Importa 3D** (o *Avatar → Importa 3D*) → scegli `GiganteFuria.glb` →
   lascia **disattivato** "Unisci mesh" (Merge meshes) → **Importa**.
2. Il modello compare nel Workspace con il nome **GiganteFuria**: premi **Play**, il gioco lo sposta da solo in
   `ReplicatedStorage → ModelliGiganti` (nell'Output: "[Giganti 3D] Modello 'Furia' pronto").
3. Per non doverlo reimportare a ogni nuova versione: tasto destro sul modello → **Salva su file** (`.rbxmx`)
   e mandalo, così viene incluso direttamente nel progetto.

Finché il modello non è importato, il Gigante della Furia usa l'aspetto costruito con le parti.
Per convertire altri modelli: `python3 tools/mesh_titan/convert.py modello.fbx colore.png normali.png rugosita.png metallo.png uscita.glb NomeAspetto`
(poi aggiungi l'aspetto in `MeshTitan.Skins`).

## 7. Codici regalo

`SIERIPERDUTI`, `ARCIPELAGO`, `CORPODEIFALCHI`, `BENVENUTORECLUTA`, `OLTREILMARE`, `PRIMORAID`
(Menu → Codici). Aggiungine altri in `src/server/Services/CodesService.lua`.

## 7a. Pannello Admin (tasto P)

Visibile solo agli amministratori: **Roblox Studio**, il **proprietario del gioco** e gli UserId in
`Config.lua → Admins` (oppure i nomi utente in `Config.lua → AdminNames`, ad esempio `matyy_pandini`). Ogni azione è controllata dal server, quindi i giocatori normali non possono usarlo.

- **Progressione**: livello massimo, +10/+100 livelli, statistiche al massimo, oro, gemme, giri della ruota, azzera premi.
- **Oggetti**: tutti gli oggetti con un clic o uno alla volta, tutti i game pass.
- **Sieri**: gli 8 Sieri Perduti (**per ora si ottengono SOLO da qui**), maestria massima, trasformazione (T).
- **Poteri**: immortalità, gas infinito, colpo unico, velocità x1.5/x2/x3, cura completa.
- **Mondo**: evoca giganti e boss, abbatti o rimuovi i giganti vicini, invasione, teletrasporto, ora del giorno,
  meteo (sereno, nuvoloso, pioggia, temporale), vai da un giocatore o portalo da te.
- **Storia**: completa l'obiettivo, salta a qualsiasi capitolo, storia completata.
- **Server**: annuncio a tutti (filtrato da Roblox), esperienza doppia per tutti, espelli un giocatore.

In alto scegli il **bersaglio** (tu o un altro giocatore) e scrivi un **valore** per i pulsanti che lo usano.

## 7b. Verificare la storia (comandi di prova)

In **Roblox Studio** (o se sei il proprietario del gioco) scrivi in chat: `/aiuto`, `/capitolo N`, `/passo`,
`/livello N`, `/oro N`, `/gemme N`, `/vai Zona`, `/zone`, `/cura`, `/giri N`, `/resetpremi`, `/tempo N`.
La guida completa, capitolo per capitolo, è in [`docs/GUIDA_STORIA.md`](docs/GUIDA_STORIA.md).

## 8. Personalizzare

| Cosa | Dove |
|---|---|
| Nome del gioco, velocità, difficoltà, sieri attivi | `src/shared/Config.lua` |
| Armi, rampini, uniformi, accessori | `src/shared/Data/Items.lua` |
| Isole e posizioni | `src/shared/Data/WorldLayout.lua`, `Zones.lua` |
| Storia e dialoghi | `src/shared/Data/Story.lua`, `NPCs.lua` |
| Missioni, raid | `Quests.lua`, `Raids.lua` |
| Prezzi in Robux e negozio delle gemme | `Monetization.lua` |
| Suoni, musica dinamica e suoni d'ambiente (ID del Creator Store) | `Sounds.lua` |
| Durata e probabilità del meteo | `src/server/Services/LightingService.lua` (`Weathers`) |
| Animazioni caricate da te (opzionale) | `AnimationIds.lua` |

Le animazioni sono **procedurali** (calcolate dal codice): funzionano subito senza caricare nulla.

## 9. Controlli automatici (per sviluppatori)

```bash
python3 tools/check_refs.py   # riferimenti tra servizi, remote e require
python3 tools/test_data.py    # coerenza di storia, missioni, isole, raid, negozi (serve 'luau')
python3 tools/test_world.py   # costruisce tutta la mappa, forzieri, cavallo, barca e mappa UI con un Roblox finto
```

`tools/test_world.py` controlla ogni proprietà assegnata con l'elenco ufficiale di Roblox
(`tools/tests/roblox_api.luau`, si rigenera con `python3 tools/gen_roblox_api.py globalTypes.d.luau`).

Vedi `docs/DESIGN.md` per l'architettura del codice.

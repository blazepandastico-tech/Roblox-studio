# 🎃 L'aggiornamento di Halloween

Un **file a parte**: `SieriPerduti_Halloween.rbxlx` (dal progetto `halloween.project.json`). Ha lo stesso codice
e la stessa mappa del gioco normale (`SieriPerduti.rbxlx`), ma in `ReplicatedStorage` ha l'attributo
**`Tema = "Halloween"`**: con quello acceso tutto diventa infestato. Togliendo l'attributo (o aprendo il file
normale) il gioco torna com'era.

Le foto sono in [`assets/halloween/`](../assets/halloween): le fa un **motore di disegno simulato**
(`tools/world_photo.py` e `tools/ui_photo.py`) partendo dal codice vero del gioco. **Non sono screenshot di
Roblox Studio**: luci e materiali in Studio saranno un po' diversi, la disposizione invece è la stessa.

## Come si usa

1. In Roblox Studio **File → Apri da file** → `SieriPerduti_Halloween.rbxlx` → **Play**.
2. Per il periodo di Halloween **pubblicalo sopra il gioco** (File → Pubblica su Roblox, stesso luogo).
   I progressi dei giocatori sono gli stessi del file normale: livelli, oro, gemme e oggetti restano.
3. Finito Halloween ripubblica `SieriPerduti.rbxlx` (gli oggetti della Collezione di Halloween restano a chi li ha vinti).

Per cambiare il tema da Studio senza file a parte: seleziona `ReplicatedStorage` → **Attributi** → aggiungi
`Tema` (testo) = `Halloween`, poi premi Play.

## Cosa cambia (solo l'aspetto: il gioco resta identico)

La mappa, le collisioni, i punti colpibili dei giganti e tutti i valori di gioco sono **gli stessi al
millimetro** del file normale: lo controlla `python3 tools/check_layout.py --halloween`.

- **Mondo**: case, tetti, persiane, fiori e alberi ridipinti in viola, arancione e foglie d'autunno; terreno
  autunnale; zucche intagliate (che di notte si accendono e tremolano), ragnatele, candele, scope, lapidi,
  cimiteri, spaventapasseri, calderoni, alberi secchi, campi di zucche; lampioni, cancelli e campi
  d'addestramento decorati; alcuni falò diventano verdi.
- **Cielo e luci**: tramonto viola e arancione, luna grande, più stelle, notti più scure; pipistrelli in volo,
  fantasmi a lenzuolo che appaiono e svaniscono, nebbia e fuochi fatui.
- **Giganti in costume**: testa di zucca, cappello da strega, zombie, corna, scheletro (a caso, sempre gli
  stessi per lo stesso gigante). Due boss nuovi: il **Re Zucca** e il **Gigante Fantasma**.
- **Utensili ed equipaggiamento**: bombole del gas color zucca, scie delle lame dall'arancione al viola, rampini
  arancioni, gas di Halloween. Quattro oggetti nuovi della **Collezione di Halloween**: Lanterna-Zucca,
  Cappello da Strega, Maschera di Zucca, Mantello Spettrale.
- **Cittadini** travestiti (zucca, strega, fantasma, vampiro, cestino di dolcetti).
- **Menu**: schermata iniziale infestata (luna arancione, il gigante che spunta dal Muro con gli occhi accesi,
  pipistrelli, zucche, fantasmi, foglie che cadono, titolo con carattere "horror"), pannelli viola con
  ragnatele, tutti i titoli dei menu con il carattere di Halloween.

## I 5 eventi Admin Abuse di Halloween

Nel Pannello Admin (tasto **P**) → **😈 Admin Abuse** → **🎬 Animazioni** ci sono gli eventi di Halloween
(in cima) e quelli della prima stagione. Ognuno parte con un'animazione con la regia per tutti i giocatori
(telecamera sull'evento, giocatori fermi e intoccabili per circa 16 secondi), poi dura i minuti scelti.

| Evento | Animazione d'apertura | Durante l'evento |
|---|---|---|
| 🎃 **La Notte delle Zucche** | dall'orto stregato oltre il Muro sorge il Re Zucca, le zucche esplodono | boss **Re Zucca** (si adatta al livello dei giocatori), giganti-zucca; oro x2, XP x1.5 |
| 👻 **Il Gigante Fantasma** | nebbia gelida, un gigante spettrale attraversa le mura | boss **Gigante Fantasma**, giganti fantasma: **ognuno vale 3 gemme**; XP x2, danni x1.5 |
| 💀 **Il Risveglio dei Caduti** | fulmini verdi sul cimitero, i giganti escono dalla terra | i giganti risorgono vicino ai giocatori; **XP x3**, oro x1.5 |
| 🍬 **Dolcetto o Scherzetto** | la Strega Bestia lancia zucche oltre il Muro | **zucche piene di dolci** vicino a ogni giocatore: oro, gemme ed esperienza... o uno scherzetto; **oro x3** |
| 🌕 **La Luna di Sangue** | la luna diventa rossa, il Colosso contro il cielo, nuvole di pipistrelli | **danni x2 e gas infinito**, XP e oro x1.5 |

Nel file normale gli eventi di Halloween non compaiono (e non possono partire).

## 🎁 Premi e bonus degli eventi (li scegli tu)

Nella sezione **🎁 Premi dell'evento** accendi o spegni (valgono per il prossimo evento che fai partire o che programmi):

- **🍬 Dolcetti**: ogni gigante dell'evento abbattuto lascia un dolcetto: oro (in base al livello), a volte gemme
  (12%) o un giro della Ruota della Fortuna (2%); i boss valgono 10 volte tanto.
- **🏆 Premio finale**: a fine evento gemme (5 + 1 per gigante, fino a 30) e oro per chi ha abbattuto almeno un
  gigante; i 3 migliori cacciatori vengono annunciati e il primo vince 20 gemme in più. Nel file di Halloween chi
  abbatte almeno 3 giganti vince anche un oggetto della Collezione di Halloween che non ha ancora.
- **✨ Bonus doppi**: raddoppia i bonus di esperienza e oro dell'evento.

Nel file di Halloween Dolcetti e Premio finale sono accesi all'inizio; nel file normale sono tutti spenti.

## 📢 Annuncio

Nella casella **📢 Annuncio** scrivi un messaggio (facoltativo, al massimo 150 caratteri, passa dal filtro di
Roblox): compare nel titolo dell'evento, alla fine dell'animazione, nello striscione e negli avvisi degli eventi
programmati. Esempio: *Stasera alle 21 tutti alle Pianure Meridionali! 🎃*

## 📅 Programmare un evento (giorno, ora e annuncio)

Nella sezione **📅 Programma un evento**:

1. scegli l'**evento**;
2. scegli **giorno e ora** con i pulsanti (📆 Oggi, 📆 Domani, ±1 giorno, ±1 ora, ±10 minuti, ±1 minuto) oppure
   scrivi la data nel **VALORE** in alto (`31/10 21:30`, `31/10/2026 21:30` o solo `21:30`) e premi **✏️ VALORE**;
   l'ora è quella **del tuo computer**;
3. la **durata** è quella scelta in 🎬 Animazioni, i **premi** e l'**annuncio** quelli scelti sopra;
4. premi **📅 PROGRAMMA QUESTO EVENTO**.

Cosa succede:
- il programma è salvato e condiviso con **tutti i server** del gioco (DataStore + MessagingService);
- **30, 10, 5 e 1 minuto prima** tutti i giocatori ricevono un avviso (con il tuo annuncio) e nell'ultima ora lo
  striscione in alto mostra il conto alla rovescia;
- all'ora giusta l'evento **parte da solo** in ogni server, con l'animazione; chi entra in un server durante
  l'evento lo trova già in corso (con i minuti che restano);
- l'elenco **Eventi programmati** mostra quando parte, i premi e l'annuncio; **❌ Annulla** lo toglie.

Limiti: al massimo 20 eventi programmati, fino a 60 giorni prima; due eventi programmati non possono
sovrapporsi. In Studio serve **"Enable Studio Access to API Services"**, altrimenti il programma vale solo per quel server.

## Per sviluppatori

| Cosa | Dove |
|---|---|
| Tema attivo, colori di Halloween | `src/shared/Data/Tema.lua` |
| Ridipintura e decorazioni del mondo | `src/server/Services/HalloweenWorld.lua` (chiamato da `WorldBuilder`) |
| Costumi dei giganti | `src/shared/Anim/HalloweenCostumes.lua` (chiamato da `TitanBuilder`) |
| Zucche accese, pipistrelli, fantasmi, nebbia | `src/client/Controllers/HalloweenController.lua` |
| Animazioni degli eventi di Halloween | `src/client/Controllers/HalloweenShows.lua` |
| Eventi, premi, programmazione (dati) | `src/shared/Data/AbuseEvents.lua` |
| Eventi in corso, dolcetti, premio finale | `src/server/Services/AbuseService.lua` |
| Programma degli eventi | `src/server/Services/AbuseScheduleService.lua` |
| Pannello Admin Abuse | `src/client/UI/AdminPanel.lua` |

```bash
rojo build halloween.project.json -o SieriPerduti_Halloween.rbxlx
python3 tools/test_world.py --halloween          # tutte le prove con il tema di Halloween
python3 tools/check_layout.py --halloween        # la mappa di Halloween è identica a quella normale?
python3 tools/world_photo.py cartella halloween_giganti campo_notte --halloween   # foto del mondo
python3 tools/ui_photo.py cartella --halloween --caratteri fonts --sfondo foto.png  # foto dei menu
```

`tools/ui_photo.py` costruisce i menu con il codice vero (Roblox finto delle prove, `tools/tests/ui_dump.luau`) e
li disegna. Per i caratteri giusti scarica i pacchetti npm `@fontsource/creepster`, `@fontsource/montserrat`,
`@fontsource/merriweather` e `@fontsource/grenze-gotisch` in una cartella e passala con `--caratteri` (senza usa DejaVu).

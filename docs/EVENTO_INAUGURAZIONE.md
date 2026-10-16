# 🎉 Evento "Grande Inaugurazione"

L'evento di lancio di **Sieri Perduti: L'Arcipelago dei Giganti**. È già dentro al gioco: parte da solo appena pubblichi e finisce il **26 ottobre 2026 alle 00:00** (ora italiana).

Le animazioni dell'evento (il Colosso d'Oro che cade dal cielo, i fuochi d'artificio, i coriandoli e la cerimonia d'apertura) le lanci tu dal Pannello Admin, nella sezione **😈 Admin Abuse**.

## Video e immagini pronti (`assets/evento/`)

| File | Formato | Dove usarlo |
|---|---|---|
| `Inaugurazione_Trailer.mp4` | 1920×1080, 26 s | YouTube, Discord, gruppo Roblox |
| `Inaugurazione_Trailer_Verticale.mp4` | 1080×1920, 26 s | TikTok, YouTube Shorts, Instagram Reels |
| `Evento_Copertina_1920x1080.png` | 16:9 | Immagine dell'evento su Roblox, copertina YouTube, Discord |
| `Evento_Storia_1080x1920.png` | 9:16 | Storie di Instagram e TikTok, sfondo per i post verticali |
| `Evento_Quadrata_1080x1080.png` | 1:1 | Post di Instagram, annuncio su Discord |

La musica è stata creata apposta, quindi non ci sono problemi di copyright. I botti dei fuochi sono a tempo con le immagini.

Nel video si vedono, in ordine:
1. il primo razzo nel cielo stellato;
2. i fuochi sopra le mura;
3. la strada in festa con i festoni;
4. il Colosso d'Oro che cade dal cielo come una meteora;
5. il Colosso al tramonto tra i fuochi;
6. il volo con il dispositivo di manovra sopra i tetti;
7. il gran finale, con il logo, "GIOCA ORA SU ROBLOX" e il codice regalo.

Per rifare video e immagini (per esempio dopo aver cambiato le scritte in `tools/thumbnails/event.py`):

```
cd tools/thumbnails
python3 event.py renderall <cartella modello Meshy> <cartella fotogrammi> 0 1
python3 event.py music musica.wav
python3 event.py edit <cartella fotogrammi> musica.wav Inaugurazione_Trailer.mp4 Inaugurazione_Trailer_Verticale.mp4
python3 event.py posters <cartella modello Meshy> <cartella uscita>
```

Per fare prima, avvia `renderall` più volte in parallelo con `0 4`, `1 4`, `2 4` e `3 4`.

## Cosa succede nel gioco

| | |
|---|---|
| ⭐ **2x esperienza e oro** | per tutti, per tutta la durata dell'evento |
| 🎁 **Regalo di benvenuto** | 100 💎 + Medaglia dell'Inaugurazione (una volta per giocatore) |
| 🏮 **Città addobbate** | archi d'oro con la scritta, festoni di luci, stendardi e coriandoli |
| 👑 **Colosso d'Oro** | boss dell'evento: cade dal cielo come una meteora quando lo lanci da 😈 Admin Abuse. Diventa più forte se nel server ci sono più giocatori. Premio: 15 💎 + 50.000 oro a chi aiuta |
| 🎆 **Fuochi d'artificio** | quando li lanci da 😈 Admin Abuse: davanti a te, sopra tutte le città o sopra ogni giocatore |
| 🎬 **Cerimonia d'apertura** | la scena animata con i fuochi, da 😈 Admin Abuse (a un giocatore o a tutti) |
| 🏆 **8 sfide** | vedi sotto. Completarle tutte dà il **Mantello dell'Inaugurazione** (leggendario, esclusivo) + 150 💎 |
| 🎟️ **Codice regalo** | `INAUGURAZIONE` → 25.000 oro + 50 💎 + 2 Pergamene dell'esperienza |

Lo striscione in alto nello schermo mostra il bonus, quanto manca alla fine e "👑 COLOSSO D'ORO IN CAMPO!" quando il Colosso è arrivato. Cliccandolo si apre il pannello con le sfide.

Le sfide "Contro il Colosso d'Oro" e "Lo spettacolo" si completano durante gli Admin Abuse, quindi organizzane qualcuno durante l'evento.

### Le 8 sfide

| Sfida | Obiettivo | Premio |
|---|---|---|
| ⚔️ Caccia d'inaugurazione | Uccidi 30 giganti | 20 💎 + 20.000 oro |
| 🎯 Colpo da maestro | 10 giganti uccisi colpendo la nuca | 15 💎 + 15.000 oro |
| 👑 Contro il Colosso d'Oro | Aiuta a sconfiggerlo | 40 💎 + 40.000 oro |
| 📦 Cacciatore di tesori | Apri 3 forzieri nascosti | 20 💎 + 20.000 oro |
| ⛵ Lupo di mare | Visita 3 isolotti del mare aperto | 20 💎 + 20.000 oro |
| 🎆 Lo spettacolo | Guarda i fuochi d'artificio in città | 10 💎 + 10.000 oro |
| 🍺 Un brindisi | Mangia un pasto caldo in una taverna | 10 💎 + 10.000 oro |
| 🤺 Gloria nell'arena | Vinci un duello | 15 💎 + 15.000 oro |

## Cambiare le date

Le date sono in `src/shared/Data/Festival.lua` e sono scritte in **secondi Unix**:

- `Festival.Start = 0`: l'evento parte subito. Per farlo partire in un giorno preciso, scrivi qui il numero di quel giorno.
- `Festival.End = 1792969200`: fine il 26/10/2026 alle 00:00, ora italiana.

Il numero si ottiene da [epochconverter.com](https://www.epochconverter.com):
1. inserisci data e ora;
2. scegli "Local time";
3. copia il numero "Epoch timestamp".

Se cambi la data di fine, ricordati di cambiare anche la scritta **"fino al 25 ottobre"** in video e immagini (in `tools/thumbnails/event.py`).

## 😈 Admin Abuse (Pannello Admin: tasto P → 😈 Admin Abuse)

Tutti i comandi e le animazioni dell'evento sono in questa sezione del pannello. Valgono solo per il server in cui sei.

| Pulsante | Cosa fa |
|---|---|
| 😈 Annuncia ADMIN ABUSE | Grande avviso a tutti: "ADMIN ABUSE! Un amministratore è nel server" |
| 👑 Colosso d'Oro qui | Il Colosso cade dal cielo come una meteora davanti a te (perfetto per dirette e video) |
| 👑 Colosso nelle Pianure (tra 30 s) | Avvisa tutti e dopo 30 secondi lo fa cadere nelle Pianure Meridionali |
| ☄️ Solo la meteora qui | Solo l'animazione della meteora d'oro (fulmini, onde d'urto, colonna di luce), senza boss |
| 🎆 Fuochi davanti a te | Spettacolo di fuochi di 30 secondi davanti a te |
| 🏙️ Fuochi su tutte le città | Spettacolo sopra tutte le città insieme |
| 🚀 Fuochi sopra ogni giocatore | Ogni giocatore si ritrova uno spettacolo sopra la testa |
| 🎊 Coriandoli a tutti | Pioggia di coriandoli sullo schermo di tutti |
| 🎬 Cerimonia al bersaglio / a TUTTI | La scena animata dell'inaugurazione al giocatore scelto o a tutto il server |
| 🎉 Accendi / ⛔ Spegni evento | Accende o spegne l'evento (2x XP e oro, sfide, addobbi) in questo server |
| 📅 Segui le date | Torna alle date di `Festival.lua` |
| ▶️ / ⏸️ Spettacoli automatici | Accesi: il Colosso arriva da solo ogni 30 minuti, i fuochi ogni 10 e la cerimonia al primo ingresso. Spenti (normale): tutto solo con Admin Abuse |

Per avere gli spettacoli automatici in tutti i server, metti `Festival.AutoShows = true` in `src/shared/Data/Festival.lua`.

### 🎬 Animazioni: eventi a tempo della prima stagione

Sempre in **😈 Admin Abuse**, la sezione **🎬 Animazioni** fa partire un evento a tempo per tutto il server:
1. scegli **quanto dura**: 1, 3, 5, 10, 15, 30 o 60 minuti. Puoi anche scrivere i minuti nel VALORE in alto (da 1 a 120) e premere **✏️ VALORE**;
2. clicca **l'evento**. Parte subito per tutti un'**animazione d'apertura con la regia** (circa 16 secondi):
   - la telecamera di ogni giocatore passa alla regia: bande nere, lampo, raggi di luce e il titolo che si schianta sullo schermo;
   - poi la scena dell'evento, girata su un set costruito nel cielo (così nessuna casa o collina la copre) con inquadrature che seguono l'azione: primi piani dei giganti, la corsa, lo schianto, i razzi, la cavalleria;
   - il testo dell'evento scorre nella banda nera in basso, la durata e i bonus in quella in alto.

   **Durante l'animazione nessuno può fare altro**: niente movimento, rampini, attacchi, menu o interfaccia, e i giganti non possono toccare nessuno. Alla fine lo schermo sfuma al nero e ognuno torna al suo personaggio. Giganti e boss dell'evento arrivano solo dopo.

   Chi in quel momento sta guardando una scena della storia vede solo il titolo, senza regia. Chi entra a evento già iniziato vede solo cielo e striscione.
3. Per tutta la durata cambiano anche altre cose:
   - il **cielo** prende i colori dell'evento;
   - **particelle** come cenere, foglie o polvere cadono attorno ai giocatori;
   - ogni tanto succede qualcosa nel cielo (razzi, fulmini, urla);
   - in alto compare uno **striscione con il conto alla rovescia**.
4. Allo scadere del tempo compare **"EVENTO TERMINATO"**: il cielo torna normale, i giganti dell'evento spariscono e i bonus si tolgono. Puoi fermarlo prima con **⏹️ Termina l'evento in corso**. Se lanci un altro evento, sostituisce quello in corso.

| Evento | Animazione d'apertura (regia) | Durante l'evento |
|---|---|---|
| 🧱 **La Caduta del Muro** | La strada tranquilla del distretto. Poi il fulmine dorato oltre il Muro e il Gigante Vulcano che si alza dietro il Muro, ripreso col teleobiettivo dal fondo della strada mentre la telecamera sale con la sua testa: le mani arrivano da dietro e si aggrappano in cima al Muro e il vapore gli esce dal collo. La ripresa da fuori che gli gira attorno mostrando tutto il corpo aggrappato mentre ruggisce, la testa sopra il Muro con la mano in primo piano, il calcio visto da fuori dietro la sua gamba (tenendosi al Muro) che fa esplodere il cancello, la breccia fumante e il gigante che lascia la presa e sparisce | XP x2, oro x1,5. Ondate di giganti vicino a chi è nelle zone con i giganti. Arriva il Gigante Ghignante |
| 🛡️ **La Carica del Bastione** | Dall'alto del Muro, la polvere all'orizzonte. La telecamera corre accanto al Bastione, poi lo schianto contro il cancello visto da dietro. Infine il Bastione nella breccia urla e si indurisce | Oro x3, XP x1,5. Il boss Bastione (torna se viene abbattuto). Scosse di terremoto |
| 🔥 **L'Assedio di Calaneth** | Razzi rossi dai tetti e campane d'allarme. Poi il fulmine e il Gigante della Furia che esce dal vapore e urla. La telecamera lo segue mentre solleva un masso enorme e lo porta fino alla breccia per chiuderla | XP x2, oro x2. Invasione del distretto e ondate fitte. Ogni giocatore riceve un gigante alleato che combatte con lui |
| 😱 **L'Urlo della Cacciatrice** | La foresta degli alberi giganti. La telecamera corre accanto alla Cacciatrice, che poi si ferma, si gira e urla (onde d'urto, schermo sfocato). Dall'alto si vedono i giganti che corrono verso di lei da ogni parte | XP x2,5, oro x1,5. Il boss Cacciatrice. A ogni urlo arrivano giganti anomali |
| 🐎 **La Spedizione oltre le Mura** | Dall'alto del Muro, all'alba, con la fanfara, la cavalleria esce dal cancello in formazione e spara i razzi verdi. Poi la telecamera galoppa accanto ai cavalli: un razzo rosso, un razzo nero, e un gigante anomalo salta fuori e li insegue | XP x3, oro x1,5. Giganti anomali segnalati da un razzo nero: ognuno vale 5 💎 |
| ⚡ **Il Fulmine della Trasformazione** | Fulmini dorati sulle case nel temporale. Poi il fulmine gigante in mezzo alla strada: il Gigante della Furia emerge dal vapore (la telecamera sale lungo il suo corpo), urla e tira un pugno verso lo schermo | Danni x2, gas infinito, XP e oro x1,5. Temporale. I fulmini immobilizzano i giganti vicino a voi per 5 secondi |

Giganti e boss dell'evento nascono vicino ai giocatori che si trovano in una zona con i giganti, non nelle città sicure né in mare. Danno le ricompense piene.

Per cambiare bonus, colori del cielo e testi degli eventi, modifica `src/shared/Data/AbuseEvents.lua`. Quello che succede durante l'evento è in `src/server/Services/AbuseService.lua`; le animazioni sono in `src/client/Controllers/AbuseEventController.lua`.

**Idea:** annuncia su Discord e TikTok l'orario degli Admin Abuse (per esempio "sabato alle 18:00"), così i giocatori entrano tutti insieme. Nel gioco premi "😈 Annuncia ADMIN ABUSE", poi lancia fuochi, Colosso e cerimonia.

## Creare l'evento su Roblox (così appare nella pagina del gioco)

1. Apri il [Creator Hub](https://create.roblox.com/dashboard/creations) e scegli il gioco.
2. Nel menu a sinistra apri **Coinvolgimento → Eventi** (in inglese *Engagement → Events*) e premi **Crea evento**.
3. Compila con i testi qui sotto:
   - **Inizio**: il giorno della pubblicazione;
   - **Fine**: 25 ottobre 2026, 23:59;
   - **Categoria**: *Launch* / Lancio, se c'è;
   - **Immagine**: `Evento_Copertina_1920x1080.png`, se viene chiesta.
4. Pubblica. I giocatori possono premere "Avvisami" e Roblox li avvisa quando l'evento inizia.

**Titolo:**
```
🎉 Grande Inaugurazione: 2x XP e Colosso d'Oro!
```

**Descrizione:**
```
L'Arcipelago dei Giganti apre le porte! Per festeggiare:
⭐ Esperienza e oro DOPPI per tutti
👑 Il Colosso d'Oro cade dal cielo durante gli Admin Abuse: sconfiggilo insieme agli altri!
🎆 Fuochi d'artificio e sorprese negli Admin Abuse
🏆 8 sfide e il Mantello dell'Inaugurazione esclusivo
🎁 Regalo di benvenuto e codice INAUGURAZIONE
Solo fino al 25 ottobre!
```

## Testi pronti per i social

**Discord (canale annunci):**
```
@everyone 🎉 **LA GRANDE INAUGURAZIONE È INIZIATA!** 🎉

Sieri Perduti è finalmente online e festeggiamo con un evento enorme:
⭐ **2x ESPERIENZA e ORO** per tutti
😈 **ADMIN ABUSE**: il **COLOSSO D'ORO** cade dal cielo e fuochi d'artificio sopra le città (seguite gli annunci per gli orari!)
🏆 **8 sfide**: completale tutte per il **Mantello dell'Inaugurazione** (esclusivo, non tornerà più!)
🎁 Regalo di benvenuto: 100 💎 + Medaglia dell'Inaugurazione

🎟️ Codice regalo: **INAUGURAZIONE**
⏳ Solo fino al **25 ottobre**!

▶️ Gioca ora: <link del gioco>
```

**TikTok / Reels / Shorts (con il video verticale):**
```
IL COLOSSO D'ORO CADE DAL CIELO 👑🔥 Evento di lancio su Roblox: 2x XP, fuochi d'artificio e premi esclusivi! Codice: INAUGURAZIONE 🎁 Cerca "Sieri Perduti" su Roblox
#roblox #robloxgame #robloxevent #giganti #anime #robloxitalia #nuovogioco
```

**YouTube (titolo e descrizione del video orizzontale):**
```
Titolo: SIERI PERDUTI – Grande Inaugurazione | Evento di lancio su Roblox (2x XP + Colosso d'Oro)

Descrizione:
L'Arcipelago dei Giganti apre le porte! Fino al 25 ottobre: esperienza e oro doppi, Admin Abuse con il Colosso d'Oro e i fuochi d'artificio, 8 sfide e il Mantello dell'Inaugurazione esclusivo.
🎁 Codice: INAUGURAZIONE
▶️ Gioca gratis: <link del gioco>
```

**Da aggiungere in cima alla descrizione del gioco su Roblox (finché dura l'evento):**
```
🎉 EVENTO GRANDE INAUGURAZIONE fino al 25/10: 2x XP e ORO, Admin Abuse con il Colosso d'Oro, fuochi d'artificio e Mantello esclusivo! Codice: INAUGURAZIONE
```

## Programma consigliato

| Quando | Cosa pubblicare |
|---|---|
| 2 giorni prima | La storia `Evento_Storia_1080x1920.png` con scritto "Tra 2 giorni…" |
| 1 giorno prima | Il trailer verticale su TikTok/Shorts; su Discord un avviso "Domani apriamo!" |
| Giorno del lancio | Pubblica il gioco, crea l'evento su Roblox, il trailer su YouTube, l'annuncio su Discord e la `Evento_Quadrata_1080x1080.png` su Instagram |
| Il giorno stesso, la sera | Primo **Admin Abuse**: annuncialo, poi lancia fuochi, Colosso d'Oro e cerimonia a tutti e registra tutto (clip perfette per TikTok) |
| Ogni 2–3 giorni | Un Admin Abuse a un orario annunciato prima su Discord e TikTok |
| Dopo 3–4 giorni | Una clip dei fuochi d'artificio sopra la città, con lo screenshot di chi ha già il Mantello |
| Ultimi 3 giorni | "ULTIMI GIORNI per il Mantello dell'Inaugurazione!" su tutti i social |
| 26 ottobre | L'evento finisce da solo. Ringrazia la community e anticipa il prossimo aggiornamento |

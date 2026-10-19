# Sieri Perduti: L'Arcipelago dei Giganti — Guida completa del giocatore

Questa guida spiega **tutto** il gioco, così non devi finirlo per sapere come funziona: comandi, volo,
combattimento, missioni, storia, armi e attrezzatura, isole, giganti, boss, raid, tesori, premi ed eventi.
I numeri vengono direttamente dai file del gioco (`src/shared/Config.lua` e `src/shared/Data/*`).

> ⚠️ **Contiene spoiler.** La sezione 9 racconta la storia completa, con tutti i colpi di scena.
> La guida passo per passo di ogni capitolo è in [`GUIDA_STORIA.md`](GUIDA_STORIA.md).

## Indice

1. [Le basi in 2 minuti](#1-le-basi-in-2-minuti)
2. [Comandi](#2-comandi)
3. [Il tuo personaggio: livelli, statistiche, stirpi](#3-il-tuo-personaggio-livelli-statistiche-stirpi)
4. [Volare con i rampini (DMT) e il gas](#4-volare-con-i-rampini-dmt-e-il-gas)
5. [Combattimento: come si uccide un gigante](#5-combattimento-come-si-uccide-un-gigante)
6. [Equipaggiamento: lame, rampini, armi, uniformi, accessori](#6-equipaggiamento-lame-rampini-armi-uniformi-accessori)
7. [Negozi, materiali e Laboratorio](#7-negozi-materiali-e-laboratorio)
8. [Le missioni (quest)](#8-le-missioni-quest)
9. [La storia completa (SPOILER)](#9-la-storia-completa-spoiler)
10. [Il mondo: isole, zone e livelli](#10-il-mondo-isole-zone-e-livelli)
11. [Viaggiare](#11-viaggiare)
12. [I giganti](#12-i-giganti)
13. [I boss: dove sono e come batterli](#13-i-boss-dove-sono-e-come-batterli)
14. [Nemici umani](#14-nemici-umani)
15. [Raid](#15-raid)
16. [Invasioni ed eventi in mare](#16-invasioni-ed-eventi-in-mare)
17. [Tesori nascosti (tutti i 42)](#17-tesori-nascosti-tutti-i-42)
18. [PvP, duelli e taglie](#18-pvp-duelli-e-taglie)
19. [Premi: giornalieri, a tempo, Ruota della Fortuna](#19-premi-giornalieri-a-tempo-ruota-della-fortuna)
20. [Obiettivi (achievement) e classifiche](#20-obiettivi-achievement-e-classifiche)
21. [Codici](#21-codici)
22. [Gemme, negozio premium e pass](#22-gemme-negozio-premium-e-pass)
23. [I Sieri Perduti (in arrivo)](#23-i-sieri-perduti-in-arrivo)
24. [Eventi: Grande Inaugurazione, Admin Abuse, Halloween](#24-eventi-grande-inaugurazione-admin-abuse-halloween)
25. [Percorso consigliato livello per livello](#25-percorso-consigliato-livello-per-livello)
26. [Domande frequenti](#26-domande-frequenti)

---

## 1. Le basi in 2 minuti

- Sei una recluta del **Corpo dei Falchi** in un arcipelago invaso dai **giganti**. Voli con i **rampini**
  (DMT, il Dispositivo di Manovra Tridimensionale) e uccidi i giganti tagliando la **nuca**.
- Si sale di livello (fino al **2000**) con le **missioni** dei personaggi, con la **storia** (17 capitoli) e
  uccidendo giganti. Ogni livello dà **3 punti statistica**.
- Con l'**oro** compri lame, rampini, armi e uniformi migliori nelle armerie. Con i **materiali** dei boss
  costruisci al **Laboratorio** l'equipaggiamento migliore del gioco.
- Il mondo è **aperto**: cinque isole grandi più otto isolotti, raggiungibili in barca, a nuoto o con i
  traghettatori. Più vai lontano, più i giganti sono forti.
- **Morire non costa niente**: rinasci dopo 5 secondi, senza perdere oro né oggetti.
- Il prossimo obiettivo della storia è sempre scritto a destra dello schermo, con una freccia che indica dove
  andare.

## 2. Comandi

| PC | Azione |
|---|---|
| **Q / E** (tieni premuto) | rampino sinistro / destro |
| **Spazio** | salto a terra; in volo, getto di gas (spinta) |
| **W A S D** | camminare; in volo, sterzare attorno ai rampini |
| **Shift** | shift lock acceso/spento (senza: mouse libero e mira col cursore) |
| **Ctrl sinistro** | schivata |
| **Bloc Maiusc** | camminata tattica / corsa d'assalto |
| **Clic sinistro** | fendente (combo da 4 colpi) |
| **Clic destro** | arma a distanza (pistole, lance dirompenti, fucili, cannone) |
| **Z X C V** | abilità delle lame |
| **R** | cambia le lame (ricarica) |
| **F** | parla, usa, raccogli, sali in barca |
| **M** | menu (equipaggiamento, statistiche, sieri, storia, codici, impostazioni, classifiche, opzioni) |
| **B** | mappa dell'arcipelago (rotella = zoom, trascina, clic destro = segnaposto) |
| **H** | chiama il cavallo / scendi |
| **W A S D** in barca | velocità e timone (Spazio per scendere) |
| **N** | negozio premium (gemme, pass) |
| **G** | Risveglio della stirpe Valkar (solo stirpe Valkar, dal livello 500) |
| **Alt sinistro** | sblocca il cursore |

Su telefono e tablet compaiono i pulsanti a schermo; il gioco funziona anche con il controller.

**Il tutorial (Missione 0).** Appena entri, dopo il filmato iniziale, la cadetta **Mira** ti insegna i comandi
uno alla volta (si va avanti solo facendoli davvero), ti mostra le isole sulla mappa, l'interfaccia e come sono
fatti i giganti. Alla fine ricevi **300 oro, esperienza e 2 Razioni** (una volta sola). Puoi saltarlo (senza
premio) e rivederlo quando vuoi da **Menu (M) → Opzioni → Rivedi**.

## 3. Il tuo personaggio: livelli, statistiche, stirpi

### Livelli ed esperienza
- Livello massimo **2000**. Si parte con **250 oro**.
- Esperienza per passare al livello successivo: **60 + 25 × livello^1,55**.

| Livello | XP per salire | XP di una missione di quel livello | Oro di una missione | XP per gigante normale |
|---|---|---|---|---|
| 1 | 85 | 76 | 88 | 4 |
| 10 | 947 | 852 | 340 | 47 |
| 50 | 10.808 | 9.728 | 1.460 | 540 |
| 100 | 31.533 | 28.380 | 2.860 | 1.577 |
| 200 | 92.219 | 82.997 | 5.660 | 4.611 |
| 500 | 381.427 | 343.285 | 14.060 | 19.071 |
| 1000 | 1.116.769 | 1.005.092 | 28.060 | 55.838 |
| 1500 | 2.093.601 | 1.884.241 | 42.060 | 104.680 |

- Una **missione** dà il 90% dell'esperienza che serve per un livello (calcolata sul livello della missione)
  e **60 + 28 × livello** oro. Le **missioni boss** danno **2,2 volte l'XP** e **3 volte l'oro**.
- Un **gigante ucciso** dà il 5% di un livello (moltiplicato per la taglia: più è grande, più vale) e
  **(8 + 2,2 × livello) oro** per il moltiplicatore della sua classe.
- Per avere la ricompensa di un gigante devi avergli fatto **almeno il 10% dei danni**: in gruppo conta anche
  chi non dà il colpo finale.
- **In conclusione**: le missioni sono la fonte principale di XP; i giganti uccisi durante la missione sono un
  extra.

### Statistiche
Ogni livello dà **3 punti**. Ogni statistica arriva al massimo a **2000**. Si assegnano da **Menu (M) →
Statistiche**.

| Statistica | Cosa fa |
|---|---|
| **Forza** | +0,55% danni delle lame per punto |
| **Vitalità** | +18 punti vita per punto (oltre ai +6 per livello sui 100 di base) e un po' di difesa |
| **Agilità** | più gas, rampini più veloci nel recupero del cavo, camminata più veloce (fino a +8) |
| **Mira** | +0,55% danni delle armi a distanza per punto |
| **Gigante** | potenza da gigante: serve solo con i Sieri (in arrivo con il prossimo aggiornamento) |

- **Azzerare le statistiche**: dall'archivista **Odile** ad Aurion, per **25.000 oro × il tuo livello**,
  oppure con **50 gemme** nel negozio premium.
- **Consiglio**: per chi usa le lame, prima Forza e Agilità, poi Vitalità. Per chi usa lance e fucili, la Mira.
  La statistica Gigante per ora non serve.

### Valori di base
- Vita: 100 + 6 per livello + 18 per punto di Vitalità.
- Critico: 5% di probabilità, danni ×1,5. Difesa massima: 60%.
- Rinascita dopo **5 secondi**, nessuna penalità alla morte.

### Maestria delle armi
Ogni colpo andato a segno con un'arma aumenta la sua **maestria** di 1, fino a **600**. Ogni punto dà
**+0,05% danni** (+30% al massimo). La maestria delle lame sblocca anche le abilità (vedi sezione 5).

### Stirpi (bloodline)
La stirpe viene assegnata a caso alla prima partita.

| Stirpe | Probabilità | Bonus |
|---|---|---|
| **Isolano** | 45% | +5% vita, +5% esperienza |
| **Esule** | 25% | +15% potenza da gigante, +10% energia |
| **Hoshimura** | 15% | +20% efficienza del gas, +10% oro |
| **Valkar** | 10% | +20% danni delle lame, +12% velocità coi rampini. **Risveglio** (tasto G, dal livello 500): per 15 s danni ×1,5 e velocità ×1,3, ricarica 120 s. Le Lame Valkar fanno +25% in più a chi ha questa stirpe |
| **Stirpe Reale** | 5% | +25% potenza da gigante, maestria piena dei sieri, immune agli stordimenti |

- **Cambiare stirpe**: da **Odile** ad Aurion per **1.500.000 oro**, oppure con la **Pergamena degli
  Antenati**, che costa 150 gemme oppure si costruisce al Laboratorio. Il risultato è sempre casuale, con le
  probabilità della tabella.
- Per chi combatte con le lame la migliore oggi è **Valkar**. La Stirpe Reale e l'Esule diventeranno forti
  quando arriveranno i Sieri.

## 4. Volare con i rampini (DMT) e il gas

- **Q** e **E** lanciano il rampino sinistro e destro verso il punto che miri. Tienili premuti per restare
  agganciato e farti tirare. Con tutti e due i rampini voli dritto; con uno solo oscilli attorno al cavo.
- **W A S D** in volo sterzano; **Spazio** dà un getto di gas (spinta in avanti).
- **Ctrl** è la schivata: ricarica di 0,9 s e **0,3 s di invulnerabilità**. È ottima per evitare prese e
  manate.
- **Velocità massima** 180. Volando veloce rasente a muri, alberi e tetti accumuli lo **slancio cinetico**,
  fino a **+35%** di velocità.
- Un aggancio **vicino** tira più forte di uno al limite della portata. Tirare nella direzione in cui voli
  rende più che tirare all'indietro: per girare conviene oscillare.

### Il gas
| Azione | Consumo |
|---|---|
| Ogni rampino che tira | 4,5 al secondo |
| Getto (Spazio) | 15 al secondo |
| Lancio di un rampino | 1,5 |
| Schivata | 6 |
| A terra | **si ricarica** da solo di 2,5 al secondo |

- La quantità massima di gas dipende dal **rampino** che usi (da 100 a 420), dall'**Agilità**, dalla stirpe
  Hoshimura, dall'Anello Hoshimura, dall'Uniforme dei Falchi e dal pass Bombole Rinforzate.
- Per fare il pieno subito ci sono:
  - i **Depositi di Rifornimento**, presenti in ogni base (premi F), che ricaricano gas e lame;
  - la **Bombola di Gas**, che si compra all'Emporio;
  - il **pasto in taverna**.

## 5. Combattimento: come si uccide un gigante

### La regola d'oro: la NUCA
Un gigante muore **solo** se gli colpisci la **nuca**, la parte dietro il collo. I colpi sul corpo fanno
solo il **20%** dei danni. Alla nuca il danno è pieno.

- **Clic sinistro** dà il fendente, con una **combo da 4 colpi** (danni ×1 / ×1 / ×1,2 / ×1,6).
  - Portata: 13.
  - Ogni fendente colpisce al massimo 4 bersagli.
- **La velocità è danno.** Da velocità 40 a 160 i danni salgono fino a **+150%**: arriva sulla nuca in volo,
  non da fermo.
- **Taglio Perfetto**: se colpisci la nuca a velocità **≥ 70** fai **danni ×2,5**. È il modo più veloce per
  uccidere.
- **Occhi**: colpirli **acceca** il gigante per 6 secondi. I boss vengono accecati solo nel 25% dei casi e per
  meno tempo.
- **Arti**:
  - **taglia una gamba** e il gigante **cade a terra per 7 secondi**: la nuca è facilissima da colpire;
  - **taglia il braccio destro** e liberi un compagno afferrato;
  - gli arti ricrescono dopo 14 secondi.
- **Di notte** (dalle 19 alle 6) i giganti normali sono molto più lenti (×0,45). Gli anomali rallentano poco
  (×0,8), i boss per niente. Un giorno completo dura 20 minuti.

### Le lame
- Ogni colpo **consuma** le lame. Quando sono rotte fanno solo il **10%** dei danni. Premi **R** per montare
  un paio di ricambio: ci vogliono 0,8 s.
- Il numero di ricambi dipende dal modello di lame (da 2 a 10). Si ricaricano al Deposito, con il Kit Lame
  o in taverna.
- Sulle **corazze** (Bastione, giganti induriti) le lame si consumano il **doppio**.

### Abilità delle lame (si sbloccano con la maestria)
| Tasto | Abilità | Maestria | Ricarica | Effetto |
|---|---|---|---|---|
| **Z** | Taglio Rotante | 0 | 6 s | rotazione che colpisce tutto intorno |
| **X** | Affondo Fulmineo | 25 | 9 s | scatto in avanti con fendente |
| **C** | Tornado d'Acciaio | 75 | 16 s | vortice di lame |
| **V** | Danza delle Lame | 150 | 40 s | salta sulla **nuca più vicina** e la colpisce 5 volte |

La **V** è la mossa migliore contro i boss: usala quando il boss è a terra o accecato.

### Armi a distanza (clic destro)
- La **Pistola di Segnalazione** acceca se colpisci gli occhi.
- Le **Lance** si conficcano nel bersaglio, la miccia lampeggia **1,4 secondi** e poi esplodono. Sono perfette
  contro le **corazze**: gli esplosivi fanno **×2,5 danni alla corazza**.
- I **fucili** e le **pistole Ombra** fanno danni extra contro gli **umani**.

### Prese (Grab)
Se un gigante ti afferra, **premi ripetutamente** il tasto indicato per liberarti:
- servono circa 12 pressioni, da 5 a 20 in base alla differenza di livello col gigante;
- hai circa 2,6 secondi di tempo;
- se non ce la fai vieni **mangiato**: perdi il **70% della vita massima** più i danni del morso;
- un compagno può salvarti tagliando il **braccio destro** del gigante.

### Corazze e indurimento
- **Pelle indurita** (Cacciatrice, Furia, alcuni attacchi): i danni scendono a ×0,25. Aspetta che finisca
  oppure colpisci altrove.
- **Corazza del Bastione**: riduce i danni dell'80%. Va rotta prima:
  - con **esplosivi** (lance) oppure con molti colpi continui;
  - quando si spezza compare **«La corazza si è spezzata!»** e hai **12 secondi** per colpire la nuca.
- **Vapore del Vulcano**: durante la fase di vapore il boss subisce solo il **15%** dei danni e scotta chi è
  vicino. **Allontanati** e torna quando il vapore finisce.

## 6. Equipaggiamento: lame, rampini, armi, uniformi, accessori

Si equipaggia da **Menu (M) → Equipaggiamento**. Ogni oggetto ha un **livello minimo**.

### Lame
| Lame | Livello | Prezzo | Danni | Durata | Ricambi | Dove |
|---|---|---|---|---|---|---|
| Lame d'Addestramento | 1 | iniziali | 12 | 25 | 4 | le hai già |
| Lame Standard | 10 | 2.500 | 20 | 35 | 6 | Armeria del Campo, Armeria QG |
| Lame Temprate | 60 | 25.000 | 34 | 45 | 8 | Armeria QG |
| Lame del Veterano | 180 | 250.000 | 55 | 55 | 8 | Armeria di Aurion |
| Lame del Capitano | 400 | 1.500.000 | 85 | 70 | 8 | Armeria di Aurion |
| **Lame Valkar** | 700 | ricetta | 120 | 90 | 8 | Laboratorio (+25% se sei Valkar) |
| **Lame di Cristallo** | 1000 | ricetta | 165 | **400** | 2 | Laboratorio (quasi indistruttibili) |
| Lame del Nuovo Corpo | 1250 | 9.000.000 | 190 | 110 | 8 | Armeria di Revelia |
| **Lame dell'Aurora** (Divine) | 1800 | ricetta | **250** | 150 | 10 | Laboratorio, 3% dal Primordiale, 1% dal raid della Grande Marcia |

### Rampini (DMT)
| Rampino | Livello | Prezzo | Gas | Portata | Recupero | Dove |
|---|---|---|---|---|---|---|
| DMT d'Addestramento | 1 | iniziale | 100 | 115 | ×1 | lo hai già |
| DMT Standard | 15 | 5.000 | 140 | 135 | ×1,08 | Armeria del Campo, QG |
| DMT Avanzato | 120 | 80.000 | 185 | 155 | ×1,16 | Armeria QG |
| DMT della Guarnigione | 300 | 400.000 | 230 | 170 | ×1,22 | Armeria di Aurion |
| **DMT Ombra** | 550 | ricetta | 270 | 185 | ×1,32 | Laboratorio, 8% dal Corvo Nero; +15% danni a distanza |
| DMT Nuovo Modello | 1000 | 6.000.000 | 330 | 205 | ×1,42 | Armeria di Revelia |
| **DMT Valkar** | 1500 | ricetta | 420 | 235 | ×1,6 | Laboratorio |

### Armi a distanza
| Arma | Livello | Prezzo | Danni | Colpi | Note | Dove |
|---|---|---|---|---|---|---|
| Pistola di Segnalazione | 5 | 1.500 | 6 | 3 | acceca se colpisci gli occhi | Campo, QG |
| Lancia Prototipo | 250 | 600.000 | 140 | 2 | esplosione raggio 14 | Aurion |
| Pistole Ombra | 450 | 1.200.000 | 70 | 2 | ×1,5 contro umani; 5% dal Corvo Nero | Aurion |
| Lancia Dirompente | 650 | 3.500.000 | 260 | 4 | la lancia "classica" | Aurion |
| Fucile Valdoriano | 1000 | 2.000.000 | 180 | 5 | ×1,6 contro umani, portata 320 | Revelia |
| Lancia Tempesta | 1300 | 12.000.000 | 420 | 6 | esplosioni a catena | Revelia |
| **Cannone Antigigante** | 1700 | ricetta | **900** | 1 | esplosione raggio 32 | Laboratorio |

### Uniformi (armature)
| Uniforme | Livello | Prezzo | Bonus | Dove |
|---|---|---|---|---|
| Uniforme da Cadetto | 1 | iniziale | — | — |
| Uniforme della Guarnigione | 30 | 12.000 | +8% vita, 3% difesa | Campo, QG |
| Uniforme dei Falchi | 80 | 60.000 | +12% vita, +10% efficienza gas | QG; **gratis** col capitolo 4 della storia |
| Uniforme della Gendarmeria | 400 | 1.000.000 | +20% oro | Aurion |
| Armatura Valdoriana | 1000 | 3.000.000 | +30% resistenza alle esplosioni | Revelia |
| Uniforme del Nuovo Corpo | 1100 | 8.000.000 | uniforme d'élite | Revelia |
| **Mantello del Falco** | 1500 | ricetta | +10% a tutti i danni, +35% vita | Laboratorio |
| **Armatura di Cristallo** | 1800 | ricetta | **30% difesa**, +30% vita | Laboratorio |
| Mantello dell'Inaugurazione | — | evento | +5% XP | premio finale della Grande Inaugurazione |

### Accessori
| Accessorio | Livello | Bonus | Come si ottiene |
|---|---|---|---|
| Distintivo dei Primi Dieci | 10 | +5% danni | storia, capitolo 1 |
| Sciarpa Rossa | 150 | +10% critico, +5% lame | 4% dalla Cacciatrice |
| Occhiali della Ricercatrice | 250 | +15% Frammenti di Siero | storia, capitolo 6 |
| Anello Hoshimura | 600 | +12% gas | 2.500.000 oro, Armeria di Aurion |
| Chiave del Seminterrato | 750 | +10% XP | storia, capitolo 13 |
| Fascia del Guerriero | 1000 | +15% potenza da gigante | 5% dal Destriero |
| **Medaglia del Comandante** | 1800 | +10% XP e oro, +5% danni | storia, capitolo 17 (finale) |
| Medaglia dell'Inaugurazione | — | +5% XP e oro | regalo di benvenuto della Grande Inaugurazione |
| Mantello Cremisi | — | +5% oro | 400 gemme, oppure jackpot della Ruota |
| Mantello della Notte | — | +5% XP | 400 gemme, oppure Pacchetto della Recluta |
| Mantello Reale VIP | — | +5% oro e XP | pass VIP |
| Mantello dell'Alba | — | +7% XP e oro | esclusivo: offerta a tempo della Bottega Reale |
| Mantello della Tempesta | — | +6% a tutti i danni | esclusivo: offerta lampo del server |
| Mantello della Leggenda | — | +8% XP e oro, +3% danni | esclusivo: Pacchetto Leggendario |
| Collezione di Halloween | — | Lanterna +3% danni, Cappello +5% XP, Maschera +5% oro, Mantello Spettrale +5% oro e XP | premio finale degli eventi Admin Abuse di Halloween (almeno 3 giganti abbattuti) |

### Consumabili
| Oggetto | Effetto | Dove |
|---|---|---|
| **Razione** | cura il 35% della vita | Emporio, 250 oro |
| **Bombola di Gas** | pieno di gas | Emporio, 400 oro |
| **Kit Lame** | lame e ricambi nuovi | Emporio, 600 oro |
| **Fiala di Adrenalina** | +50% danni per 30 s | Laboratorio, premi, gemme |
| **Pozione dell'Oro** | oro ×2 per 30 minuti | premi, Ruota, gemme |
| **Pergamena dell'Esperienza** | XP ×2 per 15 minuti | premi, codici, gemme |
| **Pergamena degli Antenati** | cambia la stirpe a caso | Laboratorio, gemme |
| **Sigillo del Raid** | avvia un raid senza pagare l'oro | premi, Ruota, gemme, codice PRIMORAID |

Gli **Empori** (Razione, Bombola, Kit) si trovano dai vivandieri in quasi tutte le basi e dal **Vecchio Ezio**
all'Isola delle Palme.

## 7. Negozi, materiali e Laboratorio

### Armerie
| Armeria | Dove | Cosa vende |
|---|---|---|
| **Armeria del Campo** (Fenn) | Campo di Addestramento | Lame Standard, DMT Standard, Pistola di Segnalazione, Uniforme Guarnigione |
| **Armeria del Corpo dei Falchi** (Odo) | Quartier Generale | + Lame Temprate, DMT Avanzato, Uniforme dei Falchi |
| **Armeria Reale di Aurion** (Corvin) | Aurion | Lame Veterano e Capitano, DMT Guarnigione, Lancia Prototipo, Pistole Ombra, Lancia Dirompente, Uniforme Gendarmeria, Anello Hoshimura |
| **Armeria Valdoriana** (Dietz) | Revelia | Fucile Valdoriano, Lame Nuovo Corpo, DMT Nuovo Modello, Lancia Tempesta, Armatura Valdoriana, Uniforme Nuovo Corpo |

### Materiali
| Materiale | Da dove arriva |
|---|---|
| **Midollo di Gigante** | giganti e boss (il Corvo Nero ne lascia 2-5 all'80%) |
| **Cristallo Indurito** | boss, raid Pietra (1-3), Vulcano (2-5), Grande Marcia (4-8 sicuri); 10 col capitolo 12 |
| **Polvere Valdoriana** | Soldati Valdoriani (8%) e Guardie di Vael (10%), a Valdoria |
| **Frammento di Siero** | raro: 0,4% dai giganti normali, 1,5% dagli anomali, boss, raid, premi, Ruota |

### Il Laboratorio della Dott.ssa Morrow
Si trova al **Quartier Generale**, ad **Aurion** e a **Revelia**: parla con Morrow (F), scegli la ricetta e
paghi materiali e oro.

| Ricetta | Livello | Materiali | Oro |
|---|---|---|---|
| Fiala di Adrenalina | 50 | 5 Midollo | 50.000 |
| Pergamena degli Antenati | 300 | 10 Cristallo + 40 Frammenti | 500.000 |
| DMT Ombra | 550 | 25 Midollo | 2.000.000 |
| Lame Valkar | 700 | 5 Cristallo + 40 Midollo | 3.000.000 |
| Lame di Cristallo | 1000 | 30 Cristallo + 10 Frammenti | 8.000.000 |
| DMT Valkar | 1500 | 25 Cristallo + 80 Midollo | 15.000.000 |
| Mantello del Falco | 1500 | 30 Cristallo + 30 Frammenti | 25.000.000 |
| Cannone Antigigante | 1700 | 20 Cristallo + 60 Polvere | 20.000.000 |
| Armatura di Cristallo | 1800 | 80 Cristallo | 30.000.000 |
| **Lame dell'Aurora** | 1800 | 60 Cristallo + 50 Frammenti + 120 Midollo | 40.000.000 |

Ci sono anche le ricette degli 8 Sieri (da 200 a 1000 Frammenti), ma restano **bloccate** fino al prossimo
aggiornamento.

### Altri personaggi utili
- **Odile** (Aurion), archivista delle stirpi: azzera le statistiche e cambia la stirpe.
- **Il Mercante Velato** (Aurion) è il mercante dei Sieri: arriverà con il prossimo aggiornamento.
- **Maestri dei raid**: **Vesna** al QG, **Orsini** ad Aurion, **Ilyas** a Revelia.
- **Maestro Ingrid** (Arena dei Duelli): PvP e duelli.

## 8. Le missioni (quest)

### Come funzionano
1. Vai da un personaggio con il **punto esclamativo** sopra la testa e premi **F**.
2. Scegli una missione che puoi fare (il **livello minimo** è indicato) e accettala.
3. L'obiettivo compare a destra dello schermo con il contatore (es. *Giganti da 7 metri 3/7*). Contano solo i
   bersagli **della zona indicata**.
4. Completato l'obiettivo, ricevi subito **XP e oro**.

**Regole**
- Puoi avere **una sola missione attiva** alla volta. La puoi **abbandonare** dal riquadro o dal menu.
- Le missioni sono **ripetibili all'infinito**: si fanno e rifanno per salire di livello.
- La storia (sezione 9) è separata. Puoi avere una missione **e** un obiettivo della storia insieme, e spesso
  gli stessi giganti contano per tutti e due.

**Consiglio:** prendi sempre la missione **più alta** che puoi fare. Rende molto più delle precedenti e i
giganti uccisi contano anche per la storia.

### Tutte le missioni
| Personaggio | Dove | Missione | Liv. min. | Obiettivo |
|---|---|---|---|---|
| **Sergente Hilde Marr** | Recinto | Elimina 6 Giganti da 3 metri | 1 | 6 × T3 |
| | | Elimina 6 Giganti da 4 metri | 9 | 6 × T4 |
| **Lenz** | Calaneth | Ripulisci le strade | 20 | 7 × T5 |
| | | Difendi Calaneth | 40 | 7 × T7 |
| | | 👹 Abbatti il Gigante Ghignante | 60 | boss |
| **Bram** | Pianure Meridionali | Apri la strada | 70 | 7 × T7 |
| | | Caccia nelle pianure | 95 | 6 × T10 |
| **Ufficiale Roth** | Avamposto (Foresta) | Tra gli alberi | 120 | 6 × T10 |
| | | Gli anomali della foresta | 150 | 6 × T12 |
| | | 👹 Sconfiggi la Cacciatrice | 180 | boss |
| **Ulrich** | Brenn (Edenia) | Libera Brenn | 200 | 8 × T7 |
| | | La nebbia di Brenn | 240 | 6 × T10 |
| **Nils** | Ostrava | Difendi il castello | 280 | 6 × T10 |
| | | Notte a Ostrava | 310 | 6 × T12 |
| | | 👹 Sconfiggi il Fauno | 330 | boss |
| **Vogt** | Accampamento di Edenia | La gola | 350 | 6 × T12 |
| | | Giganti nel canyon | 400 | 5 × T15 |
| | | 👹 Sconfiggi il Bastione | 400 | boss |
| | | 👹 Sconfiggi lo Zanna | 430 | boss |
| **Gant** | Aurion | Arresta 7 Poliziotti Corrotti | 450 | Stohlberg |
| | | Smantella la rete | 500 | 8 poliziotti |
| **Rat** | Città Sotterranea | Ferma 7 Agenti Ombra | 550 | 7 agenti |
| | | Caccia nei vicoli | 600 | 8 agenti |
| | | 👹 Sconfiggi il Corvo Nero | 630 | boss umano |
| **Edda** | Caverna di Cristallo | Giganti di cristallo | 650 | 7 × T7 |
| | | Il cuore della caverna | 690 | 6 × T10 |
| **Ivo** | Piana di Orvel | La piana | 720 | 6 × T12 |
| | | Il tremore | 760 | 5 × T15 |
| | | 👹 Sconfiggi lo Strisciante | 780 | boss |
| **Holm** | Rovine di Halvar | Riconquista Halvar | 800 | 7 × T12 |
| | | Le rovine | 860 | 6 × T15 |
| | | 👹 Sconfiggi il Vulcano | 920 | boss |
| **Kaya** | Lande di Cenere | Oltre il muro | 900 | 6 × T15 |
| | | Lande selvagge | 960 | 6 × T15 |
| **Mila** | Trincee (Valdoria) | Infiltrazione: 8 Soldati Valdoriani | 1000 | 8 soldati |
| | | Armi viventi | 1060 | 6 × T10 |
| | | La terra di nessuno | 1130 | 5 × T15 |
| | | 👹 Sconfiggi il Destriero | 1180 | boss |
| **Falk** | Revelia | Rivolta di Revelia: 8 Soldati | 1200 | 8 soldati |
| | | Caos in città | 1280 | 6 × T12 |
| | | Le guardie di Vael | 1330 | 7 guardie |
| | | 👹 Sconfiggi la Forgia | 1420 | boss |
| **Kael** | Fortezza di Vael | Assalto alla fortezza | 1450 | 8 guardie |
| | | Esperimenti falliti | 1530 | 6 × T15 |
| | | Il laboratorio | 1580 | 8 guardie |
| | | 👹 Ferma la Furia | 1680 | boss |
| **Capitano Falkner** | Fronte della Grande Marcia | Il fronte | 1700 | 7 × T15 |
| | | Anomali della Grande Marcia | 1820 | 6 × T15 |
| | | Ferma la marcia | 1880 | 3 × Giganti della Grande Marcia |
| | | 👹 RAID: Il Gigante Primordiale | 1950 | boss |

(T3 = gigante da 3 metri, T7 = da 7 metri, e così via.)

## 9. La storia completa (SPOILER)

La storia ha **17 capitoli** divisi in **4 stagioni**. Ogni capitolo si sblocca a un certo livello e ha una
serie di obiettivi: parlare con qualcuno (F), raggiungere un luogo, uccidere giganti o nemici, battere un
boss, raggiungere un livello. Gli obiettivi si vedono a destra e in **Menu (M) → Storia**, con la freccia che
indica la strada. I passi dettagliati sono in [`GUIDA_STORIA.md`](GUIDA_STORIA.md).

### Premi della storia
| Capitolo | Premio speciale |
|---|---|
| 1 | Distintivo dei Primi Dieci |
| 4 | Uniforme dei Falchi |
| 5 | 5 Frammenti di Siero |
| 6 | Occhiali della Ricercatrice |
| 12 | 10 Cristalli Induriti |
| 13 | Chiave del Seminterrato |
| 17 | Medaglia del Comandante + 5.000.000 oro |

Ogni passo dà anche XP e oro.

Completare le stagioni dà anche gli obiettivi con gemme (30, 50, 80 e 150, vedi sezione 20).

### Stagione 1 — Vermiglia: «Il Muro Infranto»
- **Cap. 1 Recluta (liv. 1).** Cinque anni dopo la caduta del distretto di **Halvar**, entri nei Cadetti con una
  fiala spezzata al collo, l'ultimo regalo di tuo padre. Fai l'addestramento con l'Istruttore **Brehm**
  (salire sulla torre con i rampini, 5 sagome dalla nuca) e conosci il cadetto **Tobias Renz**.
- **Cap. 2 Il Recinto (liv. 5).** La **Dott.ssa Morrow** studia i giganti catturati ed è molto interessata alla
  tua fiala. Elimini T3 e T4 nel Recinto, raggiungi il livello 12 e ti presenti al Quartier Generale.
- **Cap. 3 L'Assedio di Calaneth (liv. 25).** Il **Gigante Vulcano** riappare e sfonda il cancello di
  Calaneth, come cinque anni prima. Difendi il distretto col Comandante **Weiss** e abbatti il **Ghignante**.
  Nel filmato finale un **gigante combatte contro i giganti**: è **Tobias**, che si trasforma nel **Gigante
  della Furia**.
- **Cap. 4 Oltre il Muro (liv. 70).** Entri nel Corpo dei Falchi del Capitano **Falkner** (ricevi l'uniforme).
  Prima spedizione nelle Pianure fino all'Avamposto della Foresta.
- **Cap. 5 La Cacciatrice (liv. 130).** Nella foresta un gigante intelligente dà la caccia a Tobias: è la
  **Cacciatrice**. Dentro c'è **Lyra Venn**, una compagna. È la prova che i giganti-mutaforma sono **persone
  a cui è stato iniettato un siero**.

### Stagione 2 — Edenia: «La Nebbia»
- **Cap. 6 Nebbia su Brenn (liv. 200).** Giganti nel cuore di Edenia. Al villaggio di **Brenn** c'è stata una
  **nebbia verde**: raccogli 5 bombole di nebbia. Morrow scopre che il gas **trasforma le persone in giganti**.
- **Cap. 7 La Notte del Castello (liv. 280).** Al castello di **Ostrava** i giganti attaccano di notte. Sulla
  collina il **Fauno**, un gigante peloso, lancia massi e **parla**. Dentro c'è **Siegfried Aust**, che lavora
  per **Vael**.
- **Cap. 8 Il Tradimento (liv. 350).** Sulla cresta della Gola di Edenia due compagni rivelano chi sono:
  **Varis Holt** è il **Bastione** e **Kael Dorn** è il **Vulcano**, quello che ha distrutto Halvar. Batti il
  Bastione (rompi la corazza, poi nuca).
- **Cap. 9 L'Urlo (liv. 420).** Tobias **urla** e i giganti gli obbediscono. Vael ha fatto esperimenti su di
  lui da bambino.

### Stagione 3 — Aurea e Cenere: «La Verità»
- **Cap. 10 La Capitale Corrotta (liv. 450).** Ad **Aurion** la Gendarmeria Reale protegge Vael. Una ragazza
  delle cucine, **Elise**, ti chiede i registri della polizia corrotta di Stohlberg. In realtà è **Elise
  Vellmore**, erede della **Stirpe Reale**.
- **Cap. 11 La Città Sotterranea (liv. 550).** Scendi con l'ascensore di Aurion nel regno della **Squadra Ombra**
  e del suo capo, il **Corvo Nero**.
- **Cap. 12 La Caverna di Cristallo (liv. 650).** Il padre di Elise, **Lord Ansel Vellmore**, si inietta un
  Siero Perduto e diventa lo **Strisciante**, un gigante grande come una collina che striscia verso le Mura.
  Lo fermi. **Elise diventa regina** e smaschera la corruzione.
- **Cap. 13 Ritorno ad Halvar (liv. 800).** Riconquisti il tuo distretto natale e batti il **Vulcano**. Nel
  **seminterrato** della tua vecchia casa trovi il diario di tuo padre, che rivela:
  - Vael **distilla gli Otto Giganti** nei Sieri Perduti e punta al **Siero Primordiale**;
  - tuo padre ti ha dato **l'antidoto** (la fiala spezzata);
  - oltre il mare c'è un continente, **Valdoria**.

  Serve il livello 1000 per salpare.

### Stagione 4 — Valdoria: «Oltre il Mare»
- **Cap. 14 La Traversata (liv. 1000).** Nuove uniformi, Lance Dirompenti e una nave dal Porto Orientale. A
  **Revelia** ti aspetta **Varis**, che **diserta e passa dalla tua parte**, come poi **Kael**. Nelle
  Trincee batti il **Destriero**: dentro c'è **Wren Aldous**.
- **Cap. 15 La Notte di Revelia (liv. 1200).** Rivolta nella zona d'internamento. La **Forgia** (**Lady Tessaly
  Vire**) difende i segreti di Vael. Alla fine **Tobias se ne va**, rubando le chiavi.
- **Cap. 16 La Fortezza di Vael (liv. 1450).** Nel laboratorio dove nascono i Sieri Perduti ti sbarra la
  strada **Tobias**, il Gigante della Furia. Lo fermi; poi lui si unisce a te.
- **Cap. 17 La Grande Marcia (liv. 1700).** Vael si è iniettato il **Siero Primordiale** ed è diventato il
  **Gigante Primordiale**: i Vulcani della **Grande Marcia** avanzano. Al fronte, raggiunto il livello 1950,
  c'è il **raid finale** contro il Primordiale. Sconfitto Vael, **la Marcia si ferma**. Compare **STORIA
  COMPLETATA** e ricevi la **Medaglia del Comandante**.

Dopo la fine il gioco continua: missioni, boss, raid, tesori, Laboratorio e classifiche fino al livello 2000.
I Sieri arriveranno con il prossimo aggiornamento.

## 10. Il mondo: isole, zone e livelli

Le zone **sicure** (🛡️) non hanno giganti: lì trovi negozi, missioni, corrieri e taverne.

### Vermiglia (Stagione 1, livello 1-200)
| Zona | Livello | Giganti |
|---|---|---|
| 🛡️ Campo di Addestramento | 1-10 | sagome di legno |
| Recinto dei Giganti | 1-20 | T3, T4 |
| 🛡️ Quartier Generale (QG) | — | armeria, laboratorio, raid |
| Distretto di Calaneth | 20-70 | T5, T7 (10% anomali), boss Ghignante |
| Pianure Meridionali | 70-120 | T7, T10 |
| 🛡️ Avamposto della Spedizione | — | — |
| Foresta degli Alberi Giganti | 120-200 | T10, T12 (25% anomali), boss Cacciatrice |
| Porto Orientale | — | nave per Valdoria, taverna del Gabbiano |

### Edenia (Stagione 2, livello 200-450)
| Zona | Livello | Note |
|---|---|---|
| Villaggio di Brenn | 200-280 | T7, T10 |
| Castello di Ostrava | 280-350 | T10, T12, boss Fauno |
| 🛡️ Accampamento di Edenia | — | — |
| Gola di Edenia | 350-450 | T12, T15, boss Bastione e Zanna |

### Aurea (Stagione 3, livello 450-800)
| Zona | Livello | Note |
|---|---|---|
| 🛡️ Aurion (capitale) | — | armeria, laboratorio, Odile, Mercante Velato, raid |
| Stohlberg | 450-550 | Poliziotti Corrotti |
| Città Sotterranea | 550-650 | Agenti Ombra, boss Corvo Nero (ascensore di Aurion, liv. 450) |
| Caverna di Cristallo | 650-720 | giganti di cristallo |
| Piana di Orvel | 720-800 | T12, T15, boss Strisciante |

### Cenere (Stagione 3, livello 800-1000)
| Zona | Livello | Note |
|---|---|---|
| Rovine di Halvar | 800-950 | T12, T15, boss Vulcano |
| Lande di Cenere | 900-1000 | T15, **50% anomali** |
| 🛡️ Approdo di Cenere | — | — |

### Valdoria (Stagione 4, livello 1000-2000)
Ci si arriva con la **nave del Capitano Haskel** dal Porto Orientale (livello 1000).

| Zona | Livello | Note |
|---|---|---|
| 🛡️ Porto di Revelia | — | — |
| Trincee | 1000-1200 | Soldati Valdoriani, T10, T15, boss Destriero |
| Distretto di Revelia | 1200-1450 | Guardie di Vael, T12, boss Forgia; armeria, laboratorio, raid |
| Fortezza di Vael | 1450-1700 | Guardie di Vael, T15, boss Furia |
| Fronte della Grande Marcia | 1700-2000 | T15, **Giganti della Grande Marcia (100 metri)**, boss Primordiale |

### Il mare aperto e gli isolotti
| Isolotto | Livello | Cosa c'è |
|---|---|---|
| Isola dei Gabbiani | 150-220 | scogli, T7 e T10 |
| Isola del Faro | 250-350 | il faro: dalla cima si vede tutto |
| Banco di Sabbia | 300-400 | lingua di sabbia con giganti |
| Scogli dei Naufraghi | 400-500 | relitto di una nave mercantile |
| Torre Sommersa | 600-700 | torre antica mezza sommersa |
| Rifugio dei Contrabbandieri | 850-950 | contrabbandieri armati (nemici umani) |
| Scoglio di Brace | 1250-1400 | vulcano spento, giganti feroci |
| 🛡️ Isola delle Palme | — | il mercante **Vecchio Ezio** e un deposito |

Ci sono anche l'**Arena dei Raid** (dal livello 120) e l'**Arena dei Duelli** (PvP sempre attivo).

Il mondo è aperto: puoi andare dove vuoi, il gioco ti avvisa soltanto se una zona è troppo forte per te.

## 11. Viaggiare

| Mezzo | Come |
|---|---|
| **A piedi e coi rampini** | sempre |
| **Cavallo** | tasto **H**, velocità 54 (molto più veloce che a piedi) |
| **Barca personale** | **F** ai pontili, oppure "Dammi una barca" al traghettatore. WASD per guidare, velocità 70, Spazio per scendere. Sparisce dopo 5 minuti che non la usi |
| **Corrieri** (viaggio rapido) | gratis, verso le **basi sicure che hai già visitato** |
| **Traghettatori** (nocchieri) | ai porti: ti portano su qualsiasi isola (avviso se sei sotto livello) |
| **Ascensori e passaggi** | Aurion ↔ Città Sotterranea (livello 450); Piana di Orvel ↔ Caverna di Cristallo (livello 600) |
| **Nave di Haskel** | Porto Orientale ↔ Porto di Revelia (livello 1000) |
| **Pass Viaggiatore** | viaggio rapido dal menu, ovunque tu sia |

### Taverne
Nelle 5 taverne compri un **pasto caldo** per **60 + 6 × livello** oro. Ti dà:
- vita, gas e lame al massimo;
- **+10% danni per 10 minuti**.

L'oste ti dà anche **indizi sui tesori nascosti**.

| Taverna | Dove |
|---|---|
| Taverna del Muro | Calaneth |
| Locanda del Cervo | Brenn |
| Osteria Aurea | Aurion |
| Taverna del Gabbiano | Porto Orientale |
| Osteria del Porto | Revelia |

## 12. I giganti

| Classe | Altezza | Resistenza della nuca | Dove |
|---|---|---|---|
| T3 (3 metri) | 10 studs | ×0,5 | Recinto |
| T4 | 13 | ×0,65 | Recinto |
| T5 | 16 | ×0,8 | Calaneth |
| T7 | 22 | ×1 | Calaneth, Pianure, Brenn, Caverna, Trincee |
| T10 | 32 | ×1,3 | Pianure, Foresta, Edenia, Trincee |
| T12 | 38 | ×1,55 | Foresta, Ostrava, Gola, Orvel, Halvar, Revelia |
| T15 | 48 | ×1,9 | Gola, Orvel, Halvar, Lande, Valdoria |
| Gigante della Grande Marcia | **100** | ×4 | Fronte della Grande Marcia |

**Attacchi**
- **Presa** (ti afferra: premi il tasto ripetutamente per liberarti).
- **Manata**, **pestone**, **morso**.
- **Manata sulla nuca**: si scaccia di dosso chi gli sta sulla nuca, quindi colpisci e allontanati subito.

**Anomali**
- Hanno un colore e un'andatura diversi.
- Corrono (×1,75), **saltano** verso di te e cambiano bersaglio all'improvviso.
- Valgono di più e hanno più probabilità di lasciare Frammenti di Siero (1,5%).

**Cadaveri.** Il corpo di un gigante morto evapora dopo 7 secondi.

## 13. I boss: dove sono e come batterli

I boss compaiono sempre nello stesso posto e **rinascono** dopo il tempo indicato. Danno molto oro, XP,
materiali e Frammenti di Siero. La **prima volta** che sconfiggi un tipo di boss ricevi **25 gemme**.

| Boss | Liv. | Dove | Rinascita | Drop speciali |
|---|---|---|---|---|
| **Ghignante** | 70 | Calaneth | 7 min | Midollo, Adrenalina 5% |
| **Cacciatrice** | 200 | Foresta | 10 min | Sciarpa Rossa 4%, Cristallo, Midollo |
| **Fauno** | 350 | Ostrava | 12 min | Cristallo, Midollo |
| **Bastione** | 420 | Gola di Edenia | 12 min | 2-5 Cristalli (90%) |
| **Zanna** | 450 | Gola di Edenia | 10 min | Cristallo, Midollo |
| **Corvo Nero** (umano) | 650 | Città Sotterranea | 10 min | DMT Ombra 8%, Pistole Ombra 5%, Midollo |
| **Strisciante** | 800 | Piana di Orvel | 15 min | 3-6 Cristalli, 5-10 Midollo |
| **Vulcano** | 950 | Rovine di Halvar | 15 min | 2-5 Cristalli, 6-12 Midollo |
| **Destriero** | 1200 | Trincee | 13 min | Fascia del Guerriero 5%, 3-7 Polvere |
| **Forgia** | 1450 | Revelia | 15 min | 4-8 Cristalli, Polvere |
| **Furia** | 1700 | Fortezza di Vael | 15 min | 4-8 Cristalli, 8-14 Midollo |
| **Primordiale** | 2000 | Fronte della Grande Marcia | 25 min | **Lame dell'Aurora 3%**, 8-15 Cristalli, 5-10 Frammenti (50%) |

### Strategie
- **Ghignante** (anomalo, 40 studs). Ti salta addosso e, se gli sei sulla nuca, si dà una manata per scacciarti. Tagliagli una gamba quando
  atterra da un salto e colpisci la nuca mentre è a terra.
- **Cacciatrice** (45, velocissima). Si **indurisce** (danni ×0,25) e con l'**urlo** richiama giganti. Calcia
  e afferra.
  - Quando brilla di cristallo, allontanati e uccidi i giganti evocati.
  - Torna sulla nuca appena l'indurimento finisce.
- **Fauno** (55, lento). Lancia **massi** e fa **raffiche di pietre** da lontano; ruggisce (stordisce).
  - Non restare fermo in linea d'aria: gira attorno a lui coi rampini e attacca da dietro e da vicino.
- **Bastione** (48, corazzato). La corazza toglie l'80% dei danni. Carica, pugni, pestoni.
  1. Rompila con le **lance esplosive** (×2,5 sulla corazza) o con tanti colpi continui.
  2. Al messaggio **«La corazza si è spezzata!»** hai **12 secondi** per colpire la nuca.
  3. Con la V (Danza delle Lame) è quasi automatico.
- **Zanna** (18, rapidissimo). Piccolo e veloce: morsi, calci e balzi. Colpiscilo quando atterra; la
  schivata (Ctrl) è fondamentale.
- **Corvo Nero** (umano, capitano della Squadra Ombra). Spara raffiche di 5 colpi e salta coi rampini. È
  forte e resistente (×32 vita).
  - Avvicinati in zig-zag e colpisci con le lame.
  - Le **Pistole Ombra** e il **Fucile Valdoriano** fanno danni extra agli umani.
- **Strisciante** (110 studs, striscia). Lento ma enorme: vapore, morsi, manate, pestoni. La nuca è bassa e
  lunga. Stai lontano dalla testa e attacca dai fianchi.
- **Vulcano** (190 studs).
  - Nella **fase di vapore** subisce solo il 15% dei danni e scotta chi è vicino: **allontanati**.
  - Finito il vapore, sali in alto coi rampini e scendi in picchiata sulla nuca con un Taglio Perfetto.
  - È lentissimo ma i pestoni fanno molto male.
- **Destriero** (quadrupede, velocissimo). Ha un **cannone** sulla schiena, carica, morde. Schiva il cannone
  (esplosivo) e attaccalo quando si ferma dopo una carica.
- **Forgia**. Fa spuntare **spine di cristallo** dal terreno, crea un'**arena di spine** attorno a sé, colpisce
  col martello e spara con la balestra. Resta in aria coi rampini (le spine colpiscono a terra) e scendi solo
  per la nuca.
- **Furia** (Tobias). Pugni, calci, **ruggito** (stordisce), presa, indurimento e salti. È come la Cacciatrice
  ma più potente. Usa Adrenalina e V quando è stordito o a terra.
- **Primordiale** (Vael, 240 studs, boss finale, si fa in gruppo).
  - Ha **3 fasi**: a 2/3 e a 1/3 della vita richiama i giganti della Grande Marcia.
  - Usa vapore, spine, arena di spine, raffiche di pietre e il **Dominio** (un urlo che stordisce chi è
    vicino).
  - Attacca a ondate: uccidi gli evocati, schiva il vapore, colpisci la nuca dall'alto.
  - Il **raid della Grande Marcia** è il modo più comodo per affrontarlo in squadra.

**Boss degli eventi**
- **Colosso d'Oro**: Grande Inaugurazione.
- **Re Zucca** e **Gigante Fantasma**: Halloween.

## 14. Nemici umani

| Nemico | Dove | Armi | Note |
|---|---|---|---|
| **Poliziotto Corrotto** | Stohlberg | fucile | lento; a volte lascia Razioni |
| **Agente Ombra** | Città Sotterranea | pistole | salta coi rampini; a volte lascia Bombole |
| **Soldato Valdoriano** | Trincee, Revelia | fucile a lunga gittata | lascia Polvere Valdoriana (8%) |
| **Guardia di Vael** | Revelia, Fortezza | lance **esplosive** | salta coi rampini, resistente; Polvere (10%) |
| **Contrabbandiere** | Rifugio dei Contrabbandieri | pistole | lascia Bombole |

Gli umani **sparano da lontano**: non restare fermo. Contro di loro conviene colpire in volo con le lame,
oppure usare pistole e fucili, che fanno danni extra agli umani.

## 15. Raid

I raid sono battaglie a **ondate di giganti con un boss finale**, nell'**Arena dei Raid**. Si parla con un
maestro dei raid: **Vesna** al QG, **Orsini** ad Aurion o **Ilyas** a Revelia.

- Chi **avvia** il raid paga l'oro richiesto, oppure usa un **Sigillo del Raid**. Gli altri entrano
  **gratis**.
- La lobby resta aperta **30 secondi** per far entrare la squadra. Tra un'ondata e l'altra ci sono 5 secondi.
- C'è un **tempo limite**. Se tutti muoiono o il tempo finisce, il raid è perso.
- Alla vittoria ognuno riceve oro, gemme, XP, Frammenti e possibili drop.

| Raid | Liv. | Costo | Ondate | Boss | Tempo | Premi |
|---|---|---|---|---|---|---|
| 🪵 **Assalto al Recinto** | 120 | 15.000 | 6 T4 → 7 T5 → 6 T7 (30% anomali) | Ghignante | 7 min | 25.000 oro, 15 💎, 1-3 Frammenti, Adrenalina 40% |
| 🌲 **La Caccia nella Foresta** | 300 | 90.000 | 8 T7 → 7 T10 → 6 T12 | Cacciatrice | 8 min | 120.000 oro, 25 💎, 2-5 Frammenti, Pergamena XP 30% |
| 🛡️ **Le Mura di Pietra** | 550 | 350.000 | 8 T10 → 8 T12 → 6 T15 | Bastione | 9 min | 450.000 oro, 35 💎, 3-7 Frammenti, 1-3 Cristalli (60%) |
| 🌋 **Il Risveglio del Vulcano** | 900 | 1.200.000 | 9 T12 → 8 T15 → 8 T15 (60% anomali) | Vulcano | 10 min | 1.500.000 oro, 50 💎, 5-10 Frammenti, 2-5 Cristalli (80%) |
| 👣 **La Grande Marcia** | 1500 | 5.000.000 | 10 T15 → 3 Grande Marcia → 10 T15 → 5 Grande Marcia | Primordiale | 12 min | 6.000.000 oro, 80 💎, 8-15 Frammenti, 4-8 Cristalli, **Lame dell'Aurora 1%** |

I raid sono la fonte migliore di **Cristalli Induriti** e **Frammenti**.

## 16. Invasioni ed eventi in mare

- **Invasioni**: ogni **30 minuti** una zona di caccia in cui ci sono giocatori viene invasa per **5 minuti**.
  Compare l'annuncio **«Ricompense doppie per 5 minuti»** e ogni gigante ucciso vale il doppio.
- **Eventi in mare**: mentre navighi, ogni pochi minuti può succedere una di queste cose:
  - **emerge un gigante dalle onde**;
  - compare un **relitto alla deriva** con un carico da saccheggiare (oro, gemme, bombole).

  Li vedi sulla mappa.
- **Meteo e notte**: sereno, nuvoloso, pioggia e temporali si alternano da soli. Di notte i giganti normali sono lenti:
  è il momento migliore per cacciare.

## 17. Tesori nascosti (tutti i 42)

In tutto l'arcipelago ci sono **42 forzieri**. Si apre un forziere avvicinandosi e premendo **F**; ognuno si
apre **una volta sola**.

**Premi**
- Ogni forziere dà **300 + 45 × livello oro** e il 25% di un livello di XP.
- Dà anche gemme in base al tipo: **Comune 2**, **Raro 8**, **Leggendario 25**.
- **Ogni 10 forzieri** trovati: **+30 gemme**.
- **Tutti e 42**: **+100 gemme** e l'obiettivo «Cartografo dell'Arcipelago» (+120 gemme).

**Indizi**
- Gli osti delle taverne danno indizi.
- Tipo di nascondiglio: «in alto» = sui tetti o in cima (serve il rampino); «a terra» = sul terreno o sulla
  spiaggia; «dentro» = dentro un edificio; «sotto» = sottoterra.

### Vermiglia (10)
| # | Indizio (e soluzione) | Tipo |
|---|---|---|
| 1 | Sul **camminamento del Muro Vermiglio**, a nord-est | Comune, in alto |
| 2 | Sul **tetto del mastio del Quartier Generale** | Raro, in alto |
| 3 | **Dietro il Recinto** dei giganti, sepolto | Comune, a terra |
| 4 | Sulla **spiaggia a sud di Vermiglia** | Comune, a terra |
| 5 | Sui **tetti di Calaneth** | Comune, in alto |
| 6 | In **cima agli alberi giganti** della Foresta | Raro, in alto |
| 7 | **Taverna del Muro** (Calaneth), in fondo alla sala | Comune, dentro |
| 8 | In fondo al **molo del Porto Orientale** | Comune, in alto |
| 9 | **Taverna del Gabbiano** (Porto Orientale), sotto i tavoli | Comune, dentro |
| 10 | Sopra l'**arco d'ingresso dell'Arena dei Duelli** | Raro, in alto |

### Edenia (6)
| # | Indizio | Tipo |
|---|---|---|
| 11 | In **cima al castello di Ostrava**, oltre la merlatura | Raro, in alto |
| 12 | Sulla **riva del laghetto** vicino a Ostrava | Comune, a terra |
| 13 | Sul **tetto del mulino di Brenn** | Raro, in alto |
| 14 | **Locanda del Cervo** (Brenn), angolo buio vicino al camino | Comune, dentro |
| 15 | Sulle **creste di roccia della Gola di Edenia** | Raro, in alto |
| 16 | **Spiaggia a nord-ovest** di Edenia, tra i relitti | Comune, a terra |

### Aurea (7)
| # | Indizio | Tipo |
|---|---|---|
| 17 | Sulla **cupola del Palazzo Reale** di Aurion | **Leggendario**, in alto |
| 18 | Sul **camminamento del Muro Aureo**, a sud-est | Comune, in alto |
| 19 | **Osteria Aurea**, in fondo alla sala | Comune, dentro |
| 20 | Sui **tetti di Stohlberg** | Comune, in alto |
| 21 | Nell'**angolo più buio della Città Sotterranea** | Raro, sotto |
| 22 | Tra i cristalli della **Caverna di Cristallo** | **Leggendario**, sotto |
| 23 | **Oltre la Piana di Orvel**, verso la costa: un carro abbandonato | Comune, a terra |

### Cenere (4)
| # | Indizio | Tipo |
|---|---|---|
| 24 | In cima al **Muro di Cenere** in rovina | Raro, in alto |
| 25 | Sopra una **casa bruciata nelle Rovine di Halvar** | Comune, in alto |
| 26 | Nelle **Lande di Cenere, verso ovest** | Comune, a terra |
| 27 | All'**Approdo di Cenere, dietro il pontile** | Comune, a terra |

### Valdoria (6)
| # | Indizio | Tipo |
|---|---|---|
| 28 | In **cima alla Fortezza di Vael** | **Leggendario**, in alto |
| 29 | Sui **tetti di Revelia** | Raro, in alto |
| 30 | In **fondo alle Trincee** | Comune, a terra |
| 31 | **Osteria del Porto** (Revelia), in fondo | Comune, dentro |
| 32 | Sulla **costa più a est** di Valdoria | Raro, a terra |
| 33 | Sul **Fronte della Grande Marcia**, tra la lava | **Leggendario**, a terra |

### Isolotti e Arena (9)
| # | Indizio | Tipo |
|---|---|---|
| 34 | **In cima al Faro**, sopra la lanterna | **Leggendario**, in alto |
| 35 | **Isola dei Gabbiani** (il nido) | Comune, a terra |
| 36 | **Banco di Sabbia**, nella sabbia | Raro, a terra |
| 37 | Sul **ponte del relitto** agli Scogli dei Naufraghi | Raro, in alto |
| 38 | In **cima alla Torre Sommersa** | Raro, in alto |
| 39 | **Isola delle Palme**: la X sulla sabbia | Comune, a terra |
| 40 | Nel **covo dei Contrabbandieri** (devi batterli) | **Leggendario**, a terra |
| 41 | Sull'**orlo del cratere dello Scoglio di Brace** | **Leggendario**, in alto |
| 42 | Sulla **punta dell'obelisco dell'Arena dei Raid** | Raro, in alto |

## 18. PvP, duelli e taglie

- Il **PvP è spento** di base. Lo accendi da **Menu (M) → Opzioni** oppure dal **Maestro Ingrid** all'Arena
  dei Duelli. **Nell'Arena dei Duelli è sempre attivo.**
- Si combatte solo tra giocatori che hanno il PvP acceso.
- Contro i giocatori i danni sono ridotti (**×0,55**) e un singolo colpo toglie al massimo il **22%** della
  vita: niente morti istantanee.
- Dopo un combattimento devi aspettare **20 secondi** prima di spegnere il PvP: non si scappa a metà duello.
- **Taglia**: parte da **100**. Chi ti sconfigge ti **ruba il 10%** della taglia, quindi più vinci, più la tua
  taglia sale e più vali.
- Classifica «Taglia»; obiettivi Duellante (1 vittoria), Gladiatore (50) e Ricercato (taglia 5.000).

## 19. Premi: giornalieri, a tempo, Ruota della Fortuna

Si aprono con il pulsante **🎁 Premi** a sinistra dello schermo.

### Accesso giornaliero (7 giorni di fila)
Se salti un giorno si ricomincia dal giorno 1. Ogni giorno ricevi anche **10 gemme** di accesso.

| Giorno | Premio |
|---|---|
| 1 | Borsa d'oro (l'oro di 3 missioni del tuo livello) |
| 2 | 15 gemme |
| 3 | Pozione dell'Oro + l'oro di 2 missioni |
| 4 | 2 giri della Ruota |
| 5 | 2 Pergamene XP |
| 6 | 30 gemme + l'oro di 3 missioni |
| 7 | 👑 **Forziere settimanale**: 60 gemme, 3 Frammenti, 1 Sigillo del Raid, 3 giri |

### Regali a tempo (ogni giorno, più giochi più ne apri)
| Minuti di gioco | Regalo |
|---|---|
| 3 | 3 Razioni |
| 8 | oro (1 missione) |
| 15 | 1 giro della Ruota |
| 25 | 2 Fiale di Adrenalina |
| 35 | 10 gemme |
| 50 | Pergamena XP + oro (2 missioni) |
| 70 | 2 giri della Ruota |
| 90 | 👑 Gran regalo: 25 gemme, 2 Frammenti, oro (3 missioni) |

### Ruota della Fortuna
Hai **un giro gratis ogni 20 ore**; altri giri arrivano da premi, codici e negozio. Le probabilità sono sempre
visibili.

| Premio | Probabilità |
|---|---|
| Oro (1 missione) | 28% |
| 10 gemme | 18% |
| Pozione dell'Oro | 12% |
| Pergamena XP | 12% |
| Tanto oro (4 missioni) | 12% |
| 2 Frammenti di Siero | 9% |
| 50 gemme | 5% |
| Sigillo del Raid | 3% |
| **JACKPOT: Mantello Cremisi** (150 gemme se lo hai già) | 1% |

### Bonus di gruppo e amici
- **Gruppo Roblox del gioco**: entrandoci ottieni +10% oro, 50 gemme e 2 giri.
- **Amici nello stesso server**: +10% XP per ogni amico, fino a 3 amici (+30%).

## 20. Obiettivi (achievement) e classifiche

Gli obiettivi danno **gemme** e si vedono nel menu.

| Obiettivo | Cosa fare | Gemme |
|---|---|---|
| Benvenuto, Recluta | entra nel gioco | 5 |
| Primo Sangue | uccidi il primo gigante | 5 |
| Cacciatore / Sterminatore / Flagello dei Giganti | 100 / 1.000 / 10.000 giganti | 15 / 40 / 120 |
| Colpo Preciso / Lama Infallibile | 50 / 1.000 giganti uccisi dalla nuca | 10 / 50 |
| Ammazzaboss / Leggenda delle Mura | 1 / 50 boss | 15 / 80 |
| Soldato / Veterano / Capitano / Comandante / Leggenda dell'Arcipelago | livello 50 / 200 / 500 / 1000 / 2000 | 10 / 25 / 50 / 100 / 300 |
| Il Muro Infranto / La Nebbia / La Verità / Oltre il Mare | finisci la stagione 1 / 2 / 3 / tutta la storia | 30 / 50 / 80 / 150 |
| Squadra d'Assalto / Maestro dei Raid | vinci 1 / 25 raid | 15 / 60 |
| Fedele | gioca 7 giorni di fila | 30 |
| Instancabile | 10 ore di gioco in totale | 30 |
| Compagni d'Armi / La Squadra al Completo | gioca con 1 / 3 amici nello stesso server | 10 / 25 |
| Cacciatore di Tesori / Esploratore / Cartografo dell'Arcipelago | 1 / 20 / 42 forzieri | 5 / 40 / 120 |
| Duellante / Gladiatore | 1 / 50 vittorie in PvP | 10 / 50 |
| Ricercato | taglia di 5.000 | 40 |

**Classifiche** (tabelloni al Campo di Addestramento e nel menu): **Livello**, **Giganti uccisi**, **Raid
vinti**, **Taglia**.

## 21. Codici

Si inseriscono in **Menu (M) → Codici**. Ogni codice vale una volta per giocatore.

| Codice | Premio |
|---|---|
| `SIERIPERDUTI` | 5.000 oro, 25 gemme, 1 Pergamena XP |
| `INAUGURAZIONE` | 25.000 oro, 50 gemme, 2 Pergamene XP |
| `ARCIPELAGO` | 10.000 oro, 25 gemme |
| `CORPODEIFALCHI` | 5 Razioni, 3 Bombole di Gas, 2 Kit Lame |
| `BENVENUTORECLUTA` | 2.500 oro, 10 gemme, 3 Razioni |
| `OLTREILMARE` | 2 Pergamene XP |
| `PRIMORAID` | 40 gemme, 1 Sigillo del Raid |

## 22. Gemme, negozio premium e pass

Il negozio (la **Bottega Reale**) si apre in tre modi:
- con il tasto **N**;
- con il pulsante 💎;
- parlando con il mercante **Aurelio**: ha una bancarella blu e oro al Campo di Addestramento, al Quartier Generale, ad Aurion e al Porto di Revelia (💎 sulla mappa).

Tutti i dettagli e i prezzi sono in [`NEGOZIO_ROBUX.md`](NEGOZIO_ROBUX.md).

### Come guadagnare gemme senza spendere
- accesso giornaliero (10 al giorno + calendario);
- prima vittoria contro ogni tipo di boss (25);
- raid (15-80);
- forzieri (2/8/25, +30 ogni 10, +100 per tutti);
- obiettivi;
- codici;
- Ruota;
- regali a tempo;
- eventi.

### Le offerte (scheda 🔥 Offerte)
- **Primo acquisto**: il primo acquisto con Robux raddoppia le gemme dei pacchetti di gemme, oppure regala 150 gemme con qualsiasi altro prodotto.
- **Offerta lampo del server** ⚡:
  - in ogni server ne parte una ogni 40 minuti e dura 10 minuti;
  - ha solo **10 pezzi per server**, molto scontati;
  - quando è attiva, accanto al pulsante 💎 compare un cartellino arancione con il tempo che resta;
  - ogni giocatore la può prendere una volta.
- **Offerte a tempo** ⏳: ogni 6 ore escono 3 nuove offerte, uguali in tutti i server. Ognuna si prende una volta per turno.
- Dentro le offerte trovi gemme, materiali per il Laboratorio (Cristalli, Frammenti, Midollo), Pergamene degli Antenati, Sigilli del Raid e pozioni.
- Ci sono anche **mantelli esclusivi** che si ottengono solo qui: Mantello dell'Alba (+7% XP e oro), Mantello della Tempesta (+6% danni) e Mantello della Leggenda (+8% XP e oro, +3% danni). Se ne hai già uno, ricevi 150 gemme al suo posto.
- Ogni offerta mostra il suo **valore** calcolato con i prezzi del negozio.

### Negozio delle gemme
| Oggetto | Gemme |
|---|---|
| Sigillo del Raid | 40 |
| Pozione dell'Oro (oro ×2, 30 min, si somma al pass) | 60 |
| 2 Pergamene dell'Esperienza | 60 |
| 3 Fiale di Adrenalina | 35 |
| Pergamena degli Antenati (cambia stirpe) | 150 |
| Azzera Statistiche | 50 |
| Mantello Cremisi (+5% oro) | 400 |
| Mantello della Notte (+5% XP) | 400 |

### Pass permanenti (Robux, per sempre)
| Pass | Robux | Effetto |
|---|---|---|
| 💰 Oro Doppio | 349 | oro ×2 da giganti, missioni e raid |
| 📈 Esperienza Doppia | 399 | XP ×2 |
| ⚔️ Maestria Rapida | 299 | la maestria delle armi sale il doppio |
| 🗡️ Lame Eterne | 249 | le lame durano il doppio |
| 💨 Bombole Rinforzate | 199 | +50% efficienza del gas |
| 🍀 Fortuna del Cacciatore | 449 | +50% probabilità di Frammenti e oggetti rari |
| 🏷️ Amico dei Mercanti | 199 | −20% sui prezzi in oro di armerie, empori e Laboratorio |
| 🧭 Viaggiatore | 249 | viaggio rapido dal menu, ovunque |
| 👑 VIP dell'Arcipelago | 499 | nome dorato, Mantello Reale VIP, +10% oro e XP, 100 gemme al giorno |
| 🏆 Pacchetto Leggendario | 1.499 | tutti i pass + 1.000 gemme + Mantello della Leggenda (solo per chi non ha ancora nessun pass) |

### Monete e gemme
- **Monete d'oro**: 6 pacchetti da 49 a 1.999 R$. La quantità **cresce con il tuo livello**: la Borsa da 49 R$ dà 42.500 monete al livello 1 e 2,5 milioni al livello 1000.
- **Gemme**:
  - 100 per 49 R$;
  - 600 per 249 R$;
  - 1.300 per 499 R$;
  - 2.800 per 999 R$;
  - 7.500 per 2.499 R$;
  - 16.000 per 4.999 R$.
- **Giri della Ruota**: 3 per 79 R$, 10 per 229 R$.
- **Pacchetto della Recluta** (99 R$, disponibile solo nelle prime **72 ore**):
  - 300 gemme;
  - 150.000 oro;
  - 3 giri;
  - Mantello della Notte;
  - 3 Pergamene XP.

Nulla di quello che si compra è obbligatorio: tutto l'equipaggiamento si ottiene giocando.

## 23. I Sieri Perduti (in arrivo)

I Sieri permettono di **trasformarsi in gigante**. Per ora sono **bloccati** e arriveranno con il prossimo
aggiornamento.

**Come si otterranno**
- casse rarissime nel mondo;
- drop dei boss;
- il **Mercante Velato** di Aurion, con un'offerta che cambia ogni 4 ore;
- il **Laboratorio**, spendendo centinaia di Frammenti.

La statistica **Gigante** ne aumenterà la potenza.

| Siero | Rarità | Liv. | Frammenti | Passiva | Abilità |
|---|---|---|---|---|---|
| Gigante della Furia | Epico | 280 | 200 | più sei ferito, più colpisci forte | Ruggito della Furia, Visione del Futuro, Calcio Rotante, Pugno Indurito |
| Gigante Zanna | Epico | 300 | 250 | il più veloce | Artigli Induriti, Frenesia della Zanna, Balzo Felino, Morso Frantumante |
| Gigante Destriero | Epico | 300 | 250 | la trasformazione dura il doppio | Corazza Panzer, Bombardamento, Corsa Instancabile, Cannone a Spalla |
| Gigante Bastione | Leggendario | 350 | 500 | -25% danni subiti | Corazza Totale, Sfondamento, Carica Corazzata, Pugno di Cristallo |
| Gigante Cacciatrice | Leggendario | 350 | 500 | critici più forti | Cristallo Protettivo, Furia della Cacciatrice, Richiamo dei Giganti, Calcio Indurito |
| Gigante Fauno | Leggendario | 500 | 650 | +30% portata a distanza | Urlo della Fauno, Lancio Perfetto, Pioggia di Pietre, Lancio di Massi |
| Gigante della Forgia | Mitico | 700 | 800 | crea armi di cristallo | Balestra di Cristallo, Arena di Spine, Lance di Cristallo, Martello Indurito |
| Gigante Vulcano | Mitico | 900 | 1000 | il vapore scotta chi ti colpisce | Pugno dal Cielo, Esplosione Vulcano, Vapore Ardente, Calpestio Vulcano |

**Conviene già adesso** mettere da parte i **Frammenti di Siero**: servono anche per la Pergamena degli
Antenati, le Lame di Cristallo, il Mantello del Falco e le Lame dell'Aurora.

## 24. Eventi: Grande Inaugurazione, Admin Abuse, Halloween

### 🎉 Grande Inaugurazione (evento di lancio, fino al 25 ottobre 2026 alle 23:00 UTC)
- **XP e oro ×2** per tutti.
- **Regalo di benvenuto**: 100 gemme + Medaglia dell'Inaugurazione (+5% XP e oro).
- **Colosso d'Oro**:
  - un boss compare ogni **30 minuti** nelle **Pianure Meridionali**, con un avviso 1 minuto prima;
  - resta 10 minuti e la sua vita cresce con il numero di giocatori;
  - premio: 50.000 oro e 15 gemme.
- **Fuochi d'artificio** ogni 10 minuti sopra le città principali.
- **8 sfide**:

  | Sfida | Obiettivo | Premio |
  |---|---|---|
  | Caccia d'inaugurazione | uccidi 30 giganti | 20.000 oro, 20 gemme |
  | Colpo da maestro | 10 giganti dalla nuca | 15.000 oro, 15 gemme |
  | Contro il Colosso d'Oro | aiuta a sconfiggerlo | 40.000 oro, 40 gemme |
  | Cacciatore di tesori | apri 3 forzieri | 20.000 oro, 20 gemme |
  | Lupo di mare | visita 3 isolotti | 20.000 oro, 20 gemme |
  | Lo spettacolo | guarda i fuochi | 10.000 oro, 10 gemme |
  | Un brindisi | pasto in taverna | 10.000 oro, 10 gemme |
  | Gloria nell'arena | vinci un duello | 15.000 oro, 15 gemme |

- **Premio finale** (tutte e 8 le sfide): **150 gemme + Mantello dell'Inaugurazione** (+5% XP).

### 😈 Admin Abuse
Eventi a tempo lanciati dagli amministratori. Sono annunciati a tutti i server, con avvisi 30, 10, 5 e 1
minuto prima. Ogni evento parte con un'animazione cinematografica di circa 16 secondi: tutti i giocatori sono
fermi e intoccabili mentre guardano. Poi dura i minuti scelti.

**Prima stagione**

| Evento | Bonus |
|---|---|
| La Caduta del Muro | XP ×2 |
| La Carica del Bastione | oro ×3 |
| L'Assedio di Calaneth | ondate di giganti |
| L'Urlo della Cacciatrice | giganti richiamati |
| La Spedizione | XP ×3 |
| Il Fulmine | danni ×2 e **gas infinito** |

**Premi che l'admin può attivare**
- **Dolcetti**: ogni gigante dell'evento lascia oro, a volte gemme (12%) o un giro (2%); i boss valgono 10 volte
  tanto.
- **Premio finale**: 5 gemme + 1 per gigante (fino a 30) e oro; il primo della classifica vince 20 gemme extra.
- **Bonus doppi**: raddoppia i bonus dell'evento.

### 🎃 Halloween (versione speciale del gioco)
Il mondo diventa spettrale (zucche, nebbia, luna) ma il gioco resta identico. I 5 eventi Admin Abuse di
Halloween sono:

| Evento | Bonus |
|---|---|
| 🎃 La Notte delle Zucche | boss **Re Zucca** e giganti-zucca; oro ×2, XP ×1,5 |
| 👻 Il Gigante Fantasma | boss **Gigante Fantasma**; ogni gigante fantasma vale **3 gemme**; XP ×2, danni ×1,5 |
| 💀 Il Risveglio dei Caduti | i giganti risorgono vicino ai giocatori; **XP ×3**, oro ×1,5 |
| 🍬 Dolcetto o Scherzetto | zucche piene di dolci (oro, gemme, XP... o uno scherzetto); **oro ×3** |
| 🌕 La Luna di Sangue | **danni ×2 e gas infinito**, XP e oro ×1,5 |

Chi abbatte **almeno 3 giganti** in un evento di Halloween vince un pezzo della **Collezione di Halloween** che
non ha ancora:
- Lanterna;
- Cappello;
- Maschera;
- Mantello Spettrale.

Dettagli in [`HALLOWEEN.md`](HALLOWEEN.md).

## 25. Percorso consigliato livello per livello

| Livelli | Dove | Cosa fare | Cosa comprare / ottenere |
|---|---|---|---|
| 1-10 | Campo, Recinto | tutorial, capitolo 1-2, missioni di Hilde Marr; riscatta **tutti i codici** | Lame Standard (liv. 10) |
| 10-70 | Recinto → Calaneth | missioni di Lenz, capitolo 3, boss Ghignante | DMT Standard (15), Uniforme Guarnigione (30), Lame Temprate (60) |
| 70-200 | Pianure → Foresta | missioni di Bram e Roth, capitoli 4-5, Cacciatrice (Sciarpa Rossa), **raid del Recinto** dal 120 | Uniforme dei Falchi (cap. 4), DMT Avanzato (120), Lame Veterano (180) |
| 200-450 | Edenia | Ulrich, Nils, Vogt; capitoli 6-9; boss Fauno, Bastione, Zanna; **raid della Foresta** dal 300 | DMT Guarnigione (300), Lame del Capitano (400) |
| 450-650 | Aurea | Gant, Rat; capitoli 10-11; Corvo Nero (DMT Ombra 8%); **raid Pietra** dal 550 | Lancia Prototipo/Dirompente, Anello Hoshimura, DMT Ombra (550) |
| 650-1000 | Caverna, Orvel, Cenere | Edda, Ivo, Holm, Kaya; capitoli 12-13; Strisciante, Vulcano; **raid Vulcano** dal 900 | **Lame Valkar** (700), Cristalli dai raid |
| 1000-1450 | Valdoria | Mila, Falk; capitoli 14-15; Destriero, Forgia | Lame di Cristallo (1000), DMT Nuovo Modello, Fucile, Lancia Tempesta, Lame Nuovo Corpo (1250) |
| 1450-2000 | Fortezza, Fronte | Kael, Falkner; capitoli 16-17; Furia, Primordiale; **raid Grande Marcia** dal 1500 | DMT Valkar e Mantello del Falco (1500), Cannone (1700), Armatura di Cristallo e **Lame dell'Aurora** (1800) |

**Consigli generali**
1. Fai **sempre una missione attiva**: i giganti che uccidi per la storia contano anche per lei.
2. **Vola veloce e colpisci la nuca**: il Taglio Perfetto (×2,5) è la chiave di tutto.
3. Caccia **di notte** e durante le **invasioni** (ricompense doppie).
4. Usa le **Pergamene XP** e le **Pozioni dell'Oro** insieme alle missioni boss (×2,2 XP, ×3 oro).
5. Mangia in **taverna** prima di un boss (+10% danni).
6. Gioca con **amici** (+10% XP ciascuno) e fai i **raid** in squadra.
7. Non buttare i **Frammenti di Siero**: servono per gli oggetti migliori e per i Sieri in arrivo.
8. Ogni giorno: accesso, Ruota gratis e regali a tempo.

## 26. Domande frequenti

**Se muoio perdo qualcosa?** No. Rinasci dopo 5 secondi con tutto.

**Perché non faccio danni al gigante?** Ci sono quattro motivi possibili:
- stai colpendo il corpo invece della nuca (solo 20% dei danni);
- le lame sono rotte (premi **R**);
- il gigante è indurito o corazzato;
- è il Vulcano nella fase di vapore.

**Sono finito il gas!** Tocca terra: si ricarica da solo. Puoi anche andare a un Deposito, usare una Bombola o
mangiare in taverna.

**Non riesco a liberarmi dalla presa.** Premi il tasto **molto velocemente**. Se il gigante è di livello molto
più alto servono più pressioni: torna quando sei più forte, oppure fatti aiutare (tagliare il braccio destro
libera chi è afferrato).

**Posso rifare le missioni?** Sì, tutte quelle dei personaggi sono ripetibili all'infinito. La storia si fa una
volta.

**Come arrivo a Valdoria?** Al livello 1000, dalla nave del Capitano Haskel al Porto Orientale.

**Come arrivo alla Città Sotterranea?** Con l'ascensore di Aurion, dal livello 450.

**Quando arrivano i Sieri?** Con il prossimo aggiornamento. Intanto conserva i Frammenti.

**Qual è l'arma migliore?** Le **Lame dell'Aurora**: livello 1800, Laboratorio, 3% dal Primordiale o 1% dal raid
della Grande Marcia. Per le corazze conviene una lancia (Dirompente o Tempesta) oppure il Cannone
Antigigante.

# Pagina del gioco su Roblox: immagini e descrizione

Le immagini sono in `assets/pagina_roblox/`. Si caricano dal **Creator Hub**
(create.roblox.com → Le mie creazioni → il gioco → **Configura** / *Places & Thumbnails*):

| File | Dove va | Formato |
|---|---|---|
| `Icona_512.png` (anche `Icona_1024.png`) | **Icona** del gioco | 512×512 |
| `1_SieriPerduti_Copertina.png` | **Miniatura 1** (la prima che si vede) | 1920×1080 |
| `2_SieriPerduti_Combattimento.png` | Miniatura 2 | 1920×1080 |
| `3_SieriPerduti_Isole.png` | Miniatura 3 | 1920×1080 |
| `4_SieriPerduti_Gigante.png` | Miniatura 4 (alternativa, stile cinematografico) | 1920×1080 |

Consiglio: dopo qualche giorno guarda le statistiche (*Analytics → Acquisition*). Se poche persone
cliccano sul gioco, prova a mettere un'altra miniatura come prima e confronta.

Le immagini si rifanno con `python3 tools/thumbnails/scenes.py <cartella del modello Meshy> <uscita> 2 hero2,icon2,combat,world,hero`
e poi `python3 tools/thumbnails/compose.py <uscita> assets/pagina_roblox`.

## Titolo

**⚔️ Sieri Perduti: L'Arcipelago dei Giganti**

Quando esce un aggiornamento puoi aggiungere davanti un'etichetta, per esempio `[AGGIORNAMENTO 1]`.
Non usare nel titolo, nella descrizione o nei tag nomi di anime o serie famose: possono
far rimuovere il gioco per il copyright.

## Descrizione (italiano, già sotto i 1000 caratteri)

```
⚔️ SIERI PERDUTI: L'ARCIPELAGO DEI GIGANTI ⚔️
I giganti hanno sfondato le mura. Indossa il dispositivo di manovra, vola tra i tetti e colpisci la nuca prima che sia troppo tardi!

🗺️ 5 isole da esplorare e una storia originale in 4 stagioni
🪂 Volo con i rampini: veloce, fluido, con schivate e scie di gas
🗡️ Lame, armi e uniformi da potenziare
📈 Sali fino al livello 2000
👹 Giganti normali, anomali e boss su ogni isola
🔥 Raid in squadra contro ondate di giganti
🌦️ Giorno e notte, pioggia, temporali e città piene di vita
🧪 I leggendari Sieri dei Giganti: in arrivo nei prossimi aggiornamenti!

🎁 Premi ogni giorno, ruota della fortuna e codici regalo
💬 Codice di benvenuto: SIERIPERDUTI

🎮 Comandi: Q / E rampini • Spazio gas • Clic sinistro attacca • M menu

Metti 👍 e ⭐ per non perderti i prossimi aggiornamenti!
```

## Descrizione in inglese (facoltativa)

Roblox può mostrare la descrizione tradotta: aggiungi l'inglese in *Localizzazione* per raggiungere
giocatori di tutto il mondo.

```
⚔️ LOST SERUMS: ARCHIPELAGO OF GIANTS ⚔️
The giants broke through the walls. Gear up, grapple across the rooftops and strike the nape!

🗺️ 5 islands and an original 4-season story
🪂 Fast, smooth grappling-hook movement
🗡️ Blades, weapons and gear to upgrade
📈 Level up to 2000
👹 Normal giants, abnormals and bosses on every island
🔥 Team raids against waves of giants
🌦️ Day and night, rain, storms and living cities
🧪 The legendary Giant Serums: coming in future updates!

🎁 Daily rewards, lucky wheel and codes • Welcome code: SIERIPERDUTI
🎮 Q / E hooks • Space gas • Left click attack • M menu
```

## Impostazioni consigliate

- **Genere**: Combattimento (oppure Avventura)
- **Dispositivi**: computer, telefono e tablet (i comandi touch sono già nel gioco)
- **Giocatori per server**: 20
- **Questionario sui contenuti**: rispondi con sincerità. I combattimenti contro i giganti sono
  violenza fantasy senza sangue realistico.

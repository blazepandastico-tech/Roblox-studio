# Roblox-studio – Shop

Baseplate con menu laterale animato e finestra **Store!** (progetto [Rojo](https://rojo.space)).

## Come provarlo
1. Installa Rojo, poi nella cartella del repo: `rojo serve` e connettiti da Studio (oppure `rojo build -o Shop.rbxlx`).
2. Premi Play. A sinistra trovi il menu (Sentieri, Rinascita, Giornaliero, Regalo, Musica, **Shop**).
3. Clicca **Shop** (o premi **B**) per aprire lo Store.

## Bottoni visibili in StarterGui
Dopo `rojo serve` trovi in **StarterGui** due ScreenGui veri: `ShopMenu` (i 6 bottoni) e `ShopStore` (finestra, tab, X, titolo). Li puoi spostare, ricolorare e cambiare a mano in Studio; lo script li anima solo a runtime. `ShopStore` e' con `Enabled = false` (si apre da Shop): attivalo per vederlo mentre lo modifichi.
Per rigenerarli da zero: `python3 tools/gen_ui.py`. Le carte degli oggetti restano generate da `ShopConfig.lua`.

## Cosa c'e' dentro
- `src/shared/ShopConfig.lua` – **qui modifichi tutto**: tab, oggetti, prezzi, colori, tag (HOT!, NEW…).
- `src/client/ShopClient.client.lua` – UI e animazioni (apertura con rimbalzo, blur, raggi che girano, scia di luce, prezzi che pulsano, coriandoli all'acquisto, animale che segue il cursore).
- `src/server/ShopServer.server.lua` – validazione acquisti e ricompense (attributi del Player).

## Icona del cestino
Ritaglia l'icona in alto a sinistra della foto dello Store, caricala su Roblox (Create → Decals/Images) e incolla l'id in `Config.ShopIconImage` (es. `"rbxassetid://123456"`). In alternativa metti l'Image direttamente su `BasketImage` (store) e `Shop > Body > IconImage` (menu). Finche' e' vuoto viene usata un'emoji 🧺.

## Acquisti
- `Config.TestMode = true`: acquisti finti (nessun Robux), utile per provare.
- Per quelli veri crea un Developer Product per ogni oggetto e metti il suo id in `ProductId`.

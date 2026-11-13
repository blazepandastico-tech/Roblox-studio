# Ricerca: le uova di *Steal an Egg* (Roblox) e come le abbiamo reinterpretate

Questa pagina raccoglie cosa dicono le fonti pubbliche su **Steal an Egg** (Roblox, Place ID
`107778070777162`) e spiega come la struttura del gioco è stata tradotta nelle **140 uova originali**
di questo repository.

> **Nota sui limiti della ricerca.** I siti ufficiali Roblox e le wiki non sono raggiungibili
> direttamente dall'ambiente in cui è stato fatto il lavoro, quindi le informazioni arrivano dai risultati del motore di
> ricerca su wiki di fan e guide. Molti numeri (rendite, probabilità, moltiplicatori) **cambiano da una
> fonte all'altra** e da un aggiornamento all'altro: qui sono riportati come "secondo le fonti", con le
> discrepanze in evidenza. Nessuna fonte descrive come sono costruiti in Studio i modelli 3D delle uova
> (mesh, Part o texture).

## 1. Il ciclo di gioco

| Fase | Cosa succede (secondo le fonti) |
|---|---|
| **Velocità** | Il tapis roulant (*treadmill*) nella tua base è la fonte principale e illimitata di *Speed*; si compra il successivo con i soldi dei pet (le guide citano Celebrity, Hacker, Demonic, Angelic e Guardian Treadmill). |
| **Biomi** | Le uova spawnano nei biomi. Ogni bioma oltre il primo ha una soglia di Speed e un **guardiano** che, se ti prende, ti fa finire in ragdoll e perdere l'uovo. |
| **Spawn** | Le uova si rigenerano a intervalli (una guida parla di 5 minuti) e **ogni server tira a caso la taglia** dell'uovo quando spawna. |
| **Trasporto** | Le uova grandi sono pesanti e **ti rallentano** mentre torni alla base. |
| **Furto** | Gli altri giocatori possono farti cadere l'uovo con una **mazza da baseball** o con le **trappole** (massimo 3 a giocatore, bloccano per 5 secondi e funzionano anche sui guardiani). L'uovo è al sicuro solo dentro la base. |
| **Schiusa** | Nel recinto (*pen*) l'uovo ha un **timer di schiusa** (pannello *Growing Eggs*). Le uova più grandi ci mettono di più ma danno pet più forti. Gli upgrade del recinto sbloccano altri slot. |
| **Rendita** | Il pet guadagna soldi al secondo: *rendita base × moltiplicatore di taglia × moltiplicatore di mutazione* (× quantità, × 2 col pass x2 Money). Oltre ~125× il peso base i guadagni crescono meno (rendimenti decrescenti). |

## 2. Biomi e velocità richiesta

Le fonti concordano sui primi biomi; il numero totale varia (10, 11, 13 o 14) a seconda dell'aggiornamento
coperto dalla guida.

| Bioma | Speed | Guardiano |
|---|---|---|
| Forest | nessuna | Chicken |
| Lake | 900 | Swan |
| Desert | 10K | Scorpion |
| Jungle | 40K | Tiger |
| Snow | 170K | Yeti |
| Volcano | 700K | Cerberus / Hellhound (fonti discordi) |
| Abyss Ocean | 2,5M | Beluga Whale / Moby (fonti discordi) |
| Prehistoric | ~17–18M | T-Rex |
| Cosmic | 700M | – |
| Cherry Blossom | 2,5B | Oni Tiger / Kitsune (fonti discordi) |
| Titan Temple | ~7B | Gorilla King |
| Angels & Demons, Enchanted Forest, Aliens | 20B, 50B, 250B (solo alcune fonti) | – |

## 3. Uova e rarità

* **Rarità (10 livelli):** Common → Uncommon → Rare → Epic → Legendary → Mythic → Cosmic → Secret →
  Eternal → Divine. Nessuna fonte documenta i colori delle rarità.
* **Un uovo per pet:** ogni uovo prende il nome dal pet che schiude (ad esempio *Crane Egg* o *Koi Egg*), circa 8 per
  bioma. I conteggi cambiano da fonte a fonte: 88 uova in 11 biomi, 104 pet dalle uova dei biomi più quelli
  degli eventi, oppure 135 o 290 pet, a seconda di quale versione del gioco descrive la guida.
* **Aspetto:** secondo la wiki Fandom *tutte le uova hanno colori diversi; il colore cambia l'aspetto di
  uovo e pet ma non la rendita*. Il valore dipende da **taglia (forma) e rarità**.
* **Peso:** ogni uovo mostra un peso in **kg** (sulla bilancia della base e nell'inventario, che non sempre
  coincidono); i pesi variano enormemente (le guide riportano uova da poche centinaia di kg fino a milioni).

## 4. Mutazioni

| Mutazione | Aspetto (fonti) | Moltiplicatore (fonti discordi) |
|---|---|---|
| Silver | metallico | 1,2× – 1,25× |
| Golden | texture d'oro e particelle tipo monete | 2× – 2,5× |
| Rainbow | colori animati che ciclano | 2,5× – 3,5× |

Le guide della community danno come probabilità alla schiusa Silver 6/100, Golden 4/100, Rainbow 1/100.
Esistono anche mutazioni legate agli eventi: Parasite, Fractured, Scrambled, Spirit Bloom, Bloom, Monstrous e Luminous,
quest'ultima solo in una lista ormai datata.

## 5. Eventi e uova speciali

* **Rift:** alla *Rift Machine* della lobby si sacrificano i 3 pet richiesti e si ottiene uno di tre uova:
  Riftborn 45 %, Riftbeasts 35 % o Shattered Rift 20 %. Ci sono rarità fino a Divine ed Eternal e un sistema di *pity*.
* **Update 2 (29 agosto):** aggiunge il bioma Titan Temple, il **Monster Egg** nello store Robux con le rare
  varianti *Mecha* e l'evento a tempo **Hungry Frog**. Nell'evento si portano uova infette alla rana per ottenere
  Monster Chest.
* **Uova evento / Brainrot:** solo tramite Store o eventi come *Admin Abuse*.

## 6. Come l'abbiamo tradotto in uova originali

Non abbiamo copiato nomi, pet, guardiani o grafica del gioco: le **140 uova sono design originali**
che seguono la *struttura* emersa dalla ricerca.

| Nel gioco | Nella nostra collezione |
|---|---|
| Biomi sbloccati dalla velocità | 14 biomi nostri (Clover Meadow → Sky Citadel), con soglie di velocità nostre (`EggConfig.Biomes`) |
| 10 rarità | 10 rarità (con **Celestial** al posto di Cosmic) e colori nostri. Salendo di rarità l'uovo diventa più grande e guadagna anello d'aura, scintille, aureola e ali |
| Un uovo per pet, ~8 per bioma | 10 uova per bioma, una per rarità, ognuna con nome, colori, pattern e accessori propri |
| Colore estetico, valore da taglia e rarità | Colore e pattern definiscono il tema; rendita da `rarità × bioma × peso` |
| Peso in kg tirato allo spawn | `EggConfig.RollWeight` (log-normale + 1 % di uova enormi 3–6×) e `EggConfig.ScaleForWeight` per `Model:ScaleTo` |
| Uova pesanti rallentano | `EggConfig.CarrySpeedMultiplier(kg)` |
| Timer di schiusa più lungo per uova grandi | `EggConfig.HatchSeconds(id, kg)` + clip **hatch** (l'uovo trema e saltella) |
| Rendita = base × taglia × mutazione | `EggConfig.Income(id, kg, mutazione)` |
| Silver / Golden / Rainbow | `EggMutations.luau`: Silver, Golden, Rainbow (animata sui client) **+ Diamond** (cristallo, nostra) |
| Spawn per bioma pesato per rarità | `EggConfig.RollEgg(bioma)` + script di esempio `EggSpawner` |
| Nome, rarità e kg sopra l'uovo | `EggBillboard.luau` (nome, rarità colorata, kg, $/s, mutazione) |

Le uova sono costruite a **mattoncini** con le superfici native di Roblox: Part in materiale *Plastic*
con `TopSurface = Studs` e `BottomSurface = Inlet`, 1 voxel = 1 stud. Ogni uovo è un rig con Motor6D,
ha le clip `idle` (oscilla) e `hatch` (scossone) e gli accessori animati: aureole, anelli e ali.

## Fonti

* Biomi e velocità: [Sportskeeda](https://www.sportskeeda.com/roblox-news/all-steal-an-egg-biomes), [games.gg](https://games.gg/roblox/guides/steal-an-egg-biomes-guide/), [Beebom](https://beebom.com/all-steal-an-egg-biomes/), [Eldorado](https://www.eldorado.gg/blog/steal-an-egg/steal-an-egg-biomes-and-speed-requirements/), [robloxgameswiki](https://steal-an-egg.robloxgameswiki.com/guide/all-eggs)
* Rarità: [steal-an-egg.github.io](https://steal-an-egg.github.io/rarities/), [gameboost](https://gameboost.com/blog/steal-an-egg-all-pets), [itemku](https://www.itemku.com/en/blog/roblox/wiki-steal-an-egg/4489/)
* Uova e pet: [ShowGamer](https://showgamer.com/en/guides/5737-vse-yayca-v-steal-an-egg-pitomcy-redkost-i-sposoby-polucheniya), [Joytify](https://www.joytify.com/blog/en-us/rpg-others/roblox/steal-an-egg-pets-list/), [games.gg](https://games.gg/roblox/guides/steal-an-egg-all-eggs-pets-and-income-rates/), [Fandom – Eggs](https://stealanegg.fandom.com/wiki/Eggs)
* Peso e spawn: [allthings.how – uova grandi](https://allthings.how/steal-an-egg-how-to-get-the-biggest-eggs-with-server-hopping/), [allthings.how – soldi](https://allthings.how/steal-an-egg-how-to-get-more-money-fast-in-roblox/)
* Mutazioni: [Fandom – Mutations](https://stealanegg.fandom.com/wiki/Mutations), [stealanegg.fans](https://www.stealanegg.fans/mutations/), [stealanegghub](https://stealanegghub.com/steal-an-egg-mutations), [TechWiser](https://techwiser.com/steal-an-egg-mutations/), [GameRant](https://gamerant.com/roblox-steal-an-egg-all-mutations-how-to-get-them/)
* Formula della rendita: [Steal An Egg Calculator](https://steal-an-egg-calculator.com/)
* Tapis roulant, guardiani, trappole: [games.gg – treadmill](https://games.gg/roblox/guides/steal-an-egg-best-treadmills-ranked/), [games.gg – beginner](https://games.gg/roblox/guides/steal-an-egg-beginner-guide/), [Bloxodes](https://bloxodes.com/wiki/steal-an-egg)
* Rift ed eventi: [games.gg – Rift](https://games.gg/roblox/guides/steal-an-egg-rift-event-guide/), [GameRant – Rift](https://gamerant.com/steal-an-egg-the-rift-event-guide/), [Sportskeeda – Update 2](https://www.sportskeeda.com/roblox-news/steal-an-egg-update-2-patch-notes), [Eldorado – Titan Temple](https://www.eldorado.gg/blog/steal-an-egg/steal-an-egg-titan-temple-update/)

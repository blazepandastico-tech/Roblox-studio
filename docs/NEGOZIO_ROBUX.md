# 💎 Bottega Reale: il negozio con Robux

Il negozio si apre in tre modi:
- con il tasto **N**;
- con il pulsante 💎 a destra dello schermo;
- parlando con **Aurelio**, il mercante della **Bottega Reale**.

Aurelio ha una bancarella blu e oro, con un forziere di gemme che brilla e l'insegna "💎 BOTTEGA REALE". Si trova al **Campo di Addestramento**, al **Quartier Generale**, ad **Aurion** e al **Porto di Revelia**, ed è segnato sulla mappa con 💎.

Tutti i dati sono in [`src/shared/Data/Monetization.lua`](../src/shared/Data/Monetization.lua): prezzi, contenuti e tempi si cambiano lì.

Ci sono sei schede:

| Scheda | Cosa contiene |
|---|---|
| 🔥 **Offerte** | offerta lampo del server, 3 offerte a tempo, Pacchetto della Recluta, Pacchetto Leggendario |
| 💰 **Monete** | 6 pacchetti di monete che crescono con il livello |
| 💎 **Gemme** | 6 pacchetti di gemme |
| ♾️ **Permanenti** | 9 Game Pass e il Pacchetto Leggendario (tutti i pass insieme) |
| 🛒 **Negozio** | il negozio delle gemme (oggetti comprati con le gemme) |
| 🧭 **Viaggio** | viaggio rapido (pass Viaggiatore) |

## Cosa spinge a comprare

1. **Bonus del primo acquisto.** In cima alle offerte c'è una striscia dorata: il primo acquisto con Robux **raddoppia le gemme** dei pacchetti di gemme, mentre con qualsiasi altro prodotto regala **+150 gemme**. È la spinta più forte a fare il primo acquisto, che è quello più difficile da ottenere.
2. **Offerta lampo del server** ⚡:
   - in ogni server, ogni 40 minuti, compare un'offerta molto scontata (−43% / −67%);
   - dura **10 minuti** e ha solo **10 pezzi per server**;
   - quando parte, tutti ricevono un avviso e accanto al pulsante 💎 compare un cartellino arancione con il tempo che resta;
   - ogni volta che qualcuno la compra, tutto il server legge "⚡ Nome ha preso l'offerta lampo! Ne restano 7.", così gli altri vedono che qualcuno compra e che i pezzi finiscono;
   - i pezzi sono veri: quando finiscono, finiscono.
3. **Offerte a tempo** ⏳:
   - ogni 6 ore ne escono 3 nuove, scelte da 8, uguali in tutti i server;
   - ognuna mostra il conto alla rovescia e si prende una volta per turno;
   - chi torna nel gioco trova sempre qualcosa di nuovo.
4. **Oggetti esclusivi** ⭐: tre mantelli si ottengono **solo** qui e non si comprano in nessun altro modo:

   | Mantello | Bonus | Dove si trova |
   |---|---|---|
   | Mantello dell'Alba | +7% esperienza e +7% oro | offerta a tempo |
   | Mantello della Tempesta | +6% a tutti i danni | offerta lampo |
   | Mantello della Leggenda | +8% esperienza, +8% oro, +3% danni | Pacchetto Leggendario |

   Il migliore del gioco resta la Medaglia del Comandante (finale della storia), quindi non è pay-to-win.
5. **Valore e sconto onesti**:
   - ogni offerta mostra "Valore R$ X" e lo sconto, calcolati dai prezzi veri del negozio: gemme al prezzo del Sacchetto, monete al prezzo della Cassa, oggetti al prezzo del negozio delle gemme;
   - i materiali che non si vendono altrove hanno un valore in gemme fisso (Cristallo 25, Frammento 20, Midollo 6);
   - un controllo automatico (`tools/test_data.py`) blocca qualsiasi offerta che non convenga almeno del 15%.
6. **Monete che crescono con il livello.** Un pacchetto da 49 R$ dà 42.500 monete al livello 1 ma 3,8 milioni al livello 1500, così resta utile a tutti, anche ai giocatori più forti (che sono quelli che spendono di più).
7. **Pacchetti grandi più convenienti.** Ogni pacchetto mostra "+X% rispetto al più piccolo", calcolato davvero, e il più grande ha l'etichetta "MIGLIOR VALORE".
8. **Pacchetto Leggendario** (1.499 R$):
   - contiene tutti i 9 pass (2.891 R$ se presi uno alla volta), 1.000 gemme e il Mantello della Leggenda;
   - si vede solo a chi non ha ancora nessun pass, così nessuno paga due volte un pass che ha già.

## I prezzi

### Monete (Amount + PerLevel × livello)
| Pacchetto | R$ | Livello 1 | Livello 300 | Livello 1000 | Convenienza |
|---|---|---|---|---|---|
| Borsa di Monete | 49 | 42.500 | 790.000 | 2.540.000 | — |
| Sacco di Monete | 129 | 127.500 | 2.370.000 | 7.620.000 | +14% |
| Cassa di Monete (POPOLARE) | 299 | 319.000 | 6.000.000 | 19.300.000 | +24% |
| Forziere di Monete | 549 | 638.000 | 12.000.000 | 38.600.000 | +36% |
| Tesoro di Monete | 999 | 1.276.000 | 24.000.000 | 77.200.000 | +49% |
| Caveau Reale (MIGLIOR VALORE) | 1.999 | 2.975.000 | 55.300.000 | 177.800.000 | +72% |

### Gemme
| Pacchetto | R$ | Gemme | Convenienza |
|---|---|---|---|
| Manciata di Gemme | 49 | 100 | — |
| Sacchetto di Gemme | 249 | 600 | +18% |
| Scrigno di Gemme (POPOLARE) | 499 | 1.300 | +28% |
| Forziere di Gemme | 999 | 2.800 | +37% |
| Tesoro Reale di Gemme | 2.499 | 7.500 | +47% |
| Montagna di Gemme (MIGLIOR VALORE) | 4.999 | 16.000 | +57% |

Al primo acquisto le gemme raddoppiano.

### Pass permanenti
| Pass | R$ | Effetto |
|---|---|---|
| 💰 Oro Doppio | 349 | oro ×2 da giganti, missioni e raid |
| 📈 Esperienza Doppia | 399 | XP ×2 |
| ⚔️ **Maestria Rapida** (nuovo) | 299 | la maestria delle armi sale il doppio (abilità X, C, V prima e più danni) |
| 🗡️ **Lame Eterne** (nuovo) | 249 | le lame durano il doppio prima di spezzarsi |
| 💨 Bombole Rinforzate | 199 | +50% efficienza del gas |
| 🍀 Fortuna del Cacciatore | 449 | +50% Frammenti di Siero e oggetti rari |
| 🏷️ **Amico dei Mercanti** (nuovo) | 199 | −20% sui prezzi in oro di armerie, empori e Laboratorio |
| 🧭 Viaggiatore | 249 | viaggio rapido dal menu |
| 👑 VIP dell'Arcipelago | 499 | nome dorato, mantello VIP, +10% oro e XP, 100 gemme al giorno |
| 🏆 **Pacchetto Leggendario** | 1.499 | tutti i 9 pass + 1.000 💎 + Mantello della Leggenda (−55%) |

### Offerte a tempo (3 alla volta, cambiano ogni 6 ore)
| Offerta | R$ | Contenuto | Valore |
|---|---|---|---|
| 🏹 Kit del Cacciatore | 129 | 400 💎, 5 Adrenalina, 2 Pergamene XP, 1 Pozione dell'Oro | R$ 240 (−46%) |
| 🧪 Scorta del Laboratorio | 299 | 500 💎, 20 Cristalli, 50 Midollo | R$ 539 (−45%) |
| 🧬 Tesoro dei Frammenti | 349 | 300 💎, 40 Frammenti di Siero, 15 Cristalli | R$ 612 (−43%) |
| 🩸 Eredità della Stirpe | 249 | 400 💎, 4 Pergamene degli Antenati | R$ 415 (−40%) |
| 🌙 Notte di Caccia | 179 | 350 💎, 4 Pozioni dell'Oro, 5 Pergamene XP | R$ 307 (−42%) |
| 🔱 Assalto ai Raid | 229 | 550 💎, 8 Sigilli del Raid, 5 Adrenalina | R$ 385 (−41%) |
| 🌅 Collezione dell'Alba | 399 | **Mantello dell'Alba** (esclusivo), 500 💎, 2 Pergamene XP | esclusivo |
| 👑 Bottino del Re | 799 | 1.500 💎, le monete del Forziere al tuo livello, 20 Cristalli, 20 Frammenti | R$ 1.594 (−50%) |

### Offerte lampo del server (una ogni 40 minuti, 10 minuti, 10 pezzi)
| Offerta | R$ | Contenuto | Valore |
|---|---|---|---|
| 💎 Sacco di Gemme Lampo | 149 | 650 💎 | R$ 269 (−45%) |
| 💠 Materiali Rari Lampo | 199 | 20 Cristalli, 20 Frammenti, 40 Midollo | R$ 473 (−58%) |
| 🧪 Doppio Bottino Lampo | 99 | 150 💎, 3 Pozioni dell'Oro, 3 Pergamene XP | R$ 174 (−43%) |
| 🌩️ Mantello della Tempesta | 249 | **Mantello della Tempesta** (esclusivo), 300 💎, 3 Adrenalina | esclusivo |
| 🪙 Monete Lampo | 199 | le monete del Forziere al tuo livello | R$ 598 (−67%) |

Restano anche:
- il **Pacchetto della Recluta** (99 R$, solo nei primi 3 giorni): 300 💎, 150.000 monete, 3 giri, Mantello della Notte e 3 Pergamene XP;
- i **giri della Ruota**: 3 per 79 R$, 10 per 229 R$. Non compaiono dove i premi casuali a pagamento sono vietati, e i giri non sono mai dentro le offerte.

## Attivare la vendita su Roblox

Finché un ID vale `0`, in Studio l'acquisto è **simulato gratis** (per provarlo), mentre nel gioco pubblicato il pulsante dice "In arrivo". Le offerte lampo partono solo se il loro prodotto ha l'ID.

1. Vai su create.roblox.com → il tuo gioco → **Monetizzazione → Passes** e crea i 9 pass con gli stessi prezzi. Copia ogni ID in `PassId`.
2. Vai su **Monetizzazione → Developer Products** e crea un prodotto per ogni voce. Il nome può essere lo stesso; copia ogni ID in `ProductId`. Sono 29 prodotti:
   - `Products`: 6 di gemme, 6 di monete, 2 di giri, il Pacchetto della Recluta e il Pacchetto Leggendario (16);
   - `Offers`: le 8 offerte a tempo;
   - `FlashOffers`: le 5 offerte lampo.
3. Pubblica il gioco.

Gli acquisti sono sicuri:
- `ProcessReceipt` salva il profilo **prima** di confermare a Roblox;
- ogni ricevuta è registrata, così nessuno riceve due volte la stessa cosa;
- se il salvataggio fallisce la consegna viene annullata e Roblox riprova.

Le offerte si possono comprare solo quando sono davvero attive. Il server controlla turno, pezzi rimasti e se il giocatore le ha già prese.

**Per provarle in Studio:** dal Pannello Admin (tasto **P**) → Oggetti → **⚡ Offerta lampo ora** fai partire subito un'offerta lampo. Con **Rimuovi game pass** ricominci da zero.

## Consigli per guadagnare di più
- **Pubblicizza l'offerta lampo**: nei server pieni i 10 pezzi finiscono in fretta, e vedere gli altri comprare spinge a comprare.
- **Cambia le offerte quando vuoi**: modifichi `Offers` e `FlashOffers` in `Monetization.lua` (prezzo, contenuto, icona). Il test controlla da solo che ogni offerta convenga ancora.
- **Eventi**: durante la Grande Inaugurazione e gli Admin Abuse ci sono più giocatori online, e le offerte lampo si vedono di più. Puoi farne partire una dal Pannello Admin proprio durante l'evento.
- **Guarda i numeri**: in Creator Hub → Monetizzazione vedi quali prodotti si vendono di più. Abbassa il prezzo di quelli che non vendono, oppure aggiungi gemme al loro contenuto.

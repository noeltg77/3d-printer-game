# Balance notes: garage tier

Figures come from `scripts/dev/balance_report.gd`, which plays the garage many times with a scripted player using the real rules. Re-run it after changing any number in `data/`:

```
godot --headless --path . --script res://scripts/dev/balance_report.gd
```

It is a model, not a playtest. The character is one pair of hands with rough job times (22 game minutes to collect and restart a print, 20 to pack an order), the player buys every design as soon as it is affordable and prices everything at its typical price. It says nothing about whether the game feels good.

## Targets

- A second printer is affordable in about 30 minutes of play at 1x (three game days). From the Phase 3 "done when".
- Problems are noticeable but not constant: a failure every 10 to 15 minutes of play, not every print.
- Each preset is a real choice: Draft tempting but costly, Standard the safe default, Strong worth it in some situation.
- A player doing everything sensibly is never penalised by the seller rating.

## Where it stands (200 runs of 7 game days, 2026-10-09)

| Player | Second printer | Worth after 7 days | Sold a day | Printer busy | Ruined | Flawed | Refunded | Rating | Effect on orders |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Attentive, Standard | day 2.4 | £621 | 9.8 | 89% | 2.5% | 2.0% | 3.5% | 4.33 | x1.07 |
| Casual, Standard | day 3.4 | £527 | 7.3 | 72% | 2.7% | 1.9% | 3.2% | 4.35 | x1.07 |
| Attentive, Draft | day 2.4 | £562 | 8.6 | 51% | 3.8% | 2.9% | 12.7% | 3.14 | x0.43 |
| Attentive, Strong | day 3.4 | £469 | 6.5 | 91% | 2.4% | 1.5% | 0.3% | 4.59 | x1.18 |

"Attentive" notices a printer needs them within 10 game minutes, "casual" within an hour. Day 2.4 is 24 minutes at 1x. The day always ends in .4 because money only arrives when the courier calls at 17:00.

- **Second printer:** on target. 24 minutes for an attentive player, 34 for a casual one.
- **Failures:** about one print in 22 goes wrong on a fresh Plodder Mini, roughly one every two game days. On the low side of the target; worn parts push it up.
- **Wear:** only the nozzle wears out inside a week (about every three and a half days of printing). Spares cost under £12 a week. The other six parts only matter in a long game.

## Changed in this pass

- `rating_neutral` 4.4 to 4.2. A careful Standard player averages 4.3 once the odd broken parcel is counted, and was losing 3% of orders for it. They now gain 7%.
- `rating_demand_per_star` 0.4 to 0.55 and `min_rating_multiplier` 0.4 to 0.3. Printing everything at Draft ended a week within 2% of Standard, so the bad reviews weren't costing anything. It now ends about 10% behind, with orders at less than half.

## Not changed, worth a look

- **Strong is the worst choice with one printer.** It cuts refunds from 3.5% to 0.3% and lifts orders, but prints take 45% longer and the printer is already full. It only pays once there is spare printer time, which a second printer gives. Raising post damage for Standard (a rougher courier, weaker packaging) would make it matter sooner; that wants the packaging and courier choices from the design data.
- **Bigger designs earn less per printer hour.** Cable Clips make £3.69 an hour, the Flexi Dragon £2.06. They are still worth buying because each design's orders only fill part of the day, and long prints need the player less often, but the Dragon is the riskiest print for the least return. Prices are left alone while the product catalogue is being rebuilt.
- **Draft buys the second printer just as fast as Standard,** sometimes a day sooner. The cost comes later. That seems a fair lesson, but a beginner may not connect the refunds to the preset.

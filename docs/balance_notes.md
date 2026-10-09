# Balance notes: garage tier

Figures come from `scripts/dev/balance_report.gd`, which plays the garage many times with a scripted player using the real rules. Re-run it after changing any number in `data/`:

```
godot --headless --path . --script res://scripts/dev/balance_report.gd
```

It is a model, not a playtest. The character is one pair of hands with rough job times (22 game minutes to collect and restart a print, 20 to pack an order) and prices everything at its typical price. It says nothing about whether the game feels good.

The catalogue is far bigger than a garage can print, so the scripted player does not buy every design. They buy the one that earns most for the time it takes (printer time plus their own), then the next, until expected orders would fill 80% of the printers' day or all of the character's. Once it is the printers that are full, they save for a second one. Add `-- --designs=all` to list every design instead of the summary.

## Targets

- A second printer is affordable in about 30 minutes of play at 1x (three game days). From the Phase 3 "done when".
- Problems are noticeable but not constant: a failure every 10 to 15 minutes of play, not every print.
- Each preset is a real choice: Draft tempting but costly, Standard the safe default, Strong worth it in some situation.
- A player doing everything sensibly is never penalised by the seller rating.

## Where it stands (200 runs of 7 game days, 2026-10-09, with the 160 design Garage catalogue)

| Player | Second printer | Worth after 7 days | Sold a day | Printer busy | Designs owned | Ruined | Flawed | Refunded | Rating | Effect on orders |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Attentive, Standard | day 1.4 | £1,102 | 23.2 | 70% | 8 | 2.3% | 1.8% | 3.2% | 4.37 | x1.08 |
| Casual, Standard | day 2.4 | £808 | 15.6 | 50% | 8 | 2.4% | 1.6% | 3.3% | 4.34 | x1.07 |
| Attentive, Draft | day 1.4 | £768 | 15.9 | 34% | 8 | 3.3% | 2.6% | 11.8% | 3.17 | x0.44 |
| Attentive, Strong | day 1.4 | £1,068 | 22.2 | 83% | 8 | 2.0% | 1.6% | 0.4% | 4.58 | x1.18 |

"Attentive" notices a printer needs them within 10 game minutes, "casual" within an hour. Day 1.4 is 14 minutes at 1x. The day always ends in .4 because money only arrives when the courier calls at 17:00. "Printer busy" is across both printers once the second arrives.

- **Second printer: too fast.** 14 minutes for an attentive player and 24 for a casual one, against a target of 30. Before the catalogue it was 24 and 34.
- **Failures:** about one print in 24 goes wrong on a fresh Plodder Mini. With this many small prints that is roughly one a game day, which is on target.
- **Wear:** still only the nozzle wears out inside a week. Spares cost about £7.
- **Rating:** a careful Standard player still gains a little from it (x1.08).

## Why it sped up

The scripted player now picks from 160 designs and takes the best eight, where it used to buy all five there were. The best are much better than the old five:

- Profit for an hour of printer and character time runs from £5.18 (Button set) down to £1.80 (the old Desk Organiser and Flexi Dragon). The old Cable Clips made £3.69 an hour of printer time alone.
- Small prints win. The catalogue prices by size band, and the small bands earn most for the time: every design in the best ten is XS, S or a higher priced M.
- Category matters as much as size. Jewellery, Cosplay and Personalised earn £3.60 to £5.20 an hour; Kitchen, Home organisation and Education earn £2.10 to £2.60 for prints of the same size and time.

Nothing in `data/` was changed for this. The demand and licence fee rules in `scripts/dev/import_products.gd` are placeholders and are the first things to look at: licence fees are small beside what the best designs earn, and demand does not fall for pricier categories.

## Changed in the Phase 5 pass

- `rating_neutral` 4.4 to 4.2. A careful Standard player averages 4.3 once the odd broken parcel is counted, and was losing 3% of orders for it. They now gain 7%.
- `rating_demand_per_star` 0.4 to 0.55 and `min_rating_multiplier` 0.4 to 0.3. Printing everything at Draft ended a week within 2% of Standard, so the bad reviews weren't costing anything.

## Not changed, worth a look

- **Draft now costs a lot.** It ends the week 30% behind Standard (it was 10% with five designs), with orders at less than half. The second printer still arrives just as fast, so the cost comes later.
- **Strong is nearly as good as Standard.** It ends 3% behind, where it used to be the worst choice. With a second printer there is spare printer time for its longer prints, and it nearly removes refunds.
- **A casual player's printers sit idle half the time.** With eight designs of mostly small prints, the character's attention is the limit, not the printer.
- **Seasons are not applied.** Seasonal designs sell all year, and two of the best ten are seasonal.

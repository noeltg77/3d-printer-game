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

## Where it stands (200 runs of 7 game days, last run 2026-10-09 with all 635 products imported)

| Player | Second printer | Worth after 7 days | Sold a day | Printer busy | Designs owned | Ruined | Flawed | Refunded | Rating | Effect on orders |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Attentive, Standard | day 2.4 | £785 | 16.9 | 81% | 16 | 2.3% | 1.7% | 3.2% | 4.33 | x1.06 |
| Casual, Standard | day 4.4 | £441 | 10.1 | 53% | 16 | 2.4% | 1.8% | 3.5% | 4.34 | x1.07 |
| Attentive, Draft | day 2.4 | £492 | 11.8 | 45% | 16 | 3.2% | 2.7% | 11.9% | 3.15 | x0.43 |
| Attentive, Strong | day 3.4 | £605 | 13.4 | 88% | 16 | 1.9% | 1.4% | 0.4% | 4.59 | x1.18 |

"Attentive" notices a printer needs them within 10 game minutes, "casual" within an hour. Day 2.4 is 24 minutes at 1x. The day always ends in .4 because money only arrives when the courier calls at 17:00. "Printer busy" is across both printers once the second arrives.

- **Second printer:** on target for an attentive player at 24 minutes. A casual one takes 44, with the quickest runs at 34; it was 34 with the old five designs.
- **Failures:** about one print in 25 goes wrong on a fresh Plodder Mini, roughly one every game day and a half. On target.
- **Wear:** still only the nozzle wears out inside a week. Spares cost £5 to £10.
- **Rating:** a careful Standard player still gains a little from it (x1.06).

## Re-run after the whole catalogue came in

The table above was first measured with only the 160 Garage designs in the game. It was run again once the Spare room and Workshop products were imported (635 in all) and every figure came out the same. That is expected, and worth knowing why:

- The scripted player only chooses from designs on sale in the garage. The 475 for later tiers are held back in the game too, so they change nothing here.
- The import did not alter any Garage product's numbers. Three were renamed, and that is all.

So the garage is where the last pass left it. What the re-run cannot tell you is below.

## What the report does not cover

It plays the garage with the Phase 5 rules. Rules added since are in the game but not in the model:

- **Trends.** Every three to five days one category sells at 1.8 times its usual rate and another at 0.6. A player whose sixteen designs lean on the cool category will earn less than the table says, and one who chases the hot one more. Seasonal categories are left out of trends, and seasons themselves are still not applied.
- **Damp filament.** PLA takes five game days in the open to get wet, and a busy garage empties a spool in a day or two, so it should hardly matter in the first week. It matters for a slow starter, and for PETG and TPU later.
- **Printer upgrades and the second marketplace.** Neither is bought or used.
- **Everything after the garage.** There are no figures at all for the small unit: 462 designs become available there with demand and licence fees from the same placeholder rules, against rent of £9.99 a day. Nobody has checked that it pays.

## Changed in the catalogue pass

The first import of the catalogue gave every design the old five's demand and a licence fee of 1.2 times its price. The scripted player then took the best eight of 160 and could afford a second printer after 14 minutes. Three rules in `scripts/dev/import_products.gd` changed; nothing in the catalogue's own prices, grams or print times did.

- **Demand by size band** from XS 5, S 3.5, M 3, L 2.5 orders a day to XS 3, S 2.5, M 2, L 1.5. One design no longer fills a third of a printer's day, so a garage wants about sixteen designs, not eight. A catalogue this size should reward owning a range.
- **Dearer designs sell slower.** Demand is multiplied by the square root of (cheapest price in the band / this price). A £6.99 button set took the same orders as a £3.99 scoop; it now takes three quarters as many.
- **Licence fee** from 1.2 to 2 times the typical price. A design pays for itself in about three sales. Sixteen designs cost over £300 across the week, which is most of what holds the second printer back to day 2.4.

Tried and dropped: halving demand with a fee of 3 times the price put the second printer at day 6.4 and out of reach for a casual player; a full price correction (power 1.0) with slightly higher bands gave day 3.4 and 4.4.

## What the catalogue is worth

- Profit for an hour of printer and character time runs from £5.18 (Button set) down to £1.80 (the old Desk Organiser and Flexi Dragon). That is a property of the catalogue's prices and is unchanged.
- Small prints still earn most for the time, and category matters as much as size: Jewellery, Cosplay and Personalised earn £3.60 to £5.20 an hour, Kitchen, Home organisation and Education £2.10 to £2.60. The demand rule now takes back part of that advantage in orders a day.

## Changed in the Phase 5 pass

- `rating_neutral` 4.4 to 4.2. A careful Standard player averages 4.3 once the odd broken parcel is counted, and was losing 3% of orders for it. They now gain 7%.
- `rating_demand_per_star` 0.4 to 0.55 and `min_rating_multiplier` 0.4 to 0.3. Printing everything at Draft ended a week within 2% of Standard, so the bad reviews weren't costing anything.

## Not changed, worth a look

- **Draft costs a lot.** It ends the week 37% behind Standard, with orders at less than half. The second printer still arrives just as fast, so the cost comes later.
- **Strong is a real choice again, but a costly one.** It ends 23% behind Standard and buys the second printer a day later, for almost no refunds and the best rating. With one printer its longer prints are what hold it back.
- **A casual player's printers sit idle half the time.** With sixteen designs of mostly small prints, the character's attention is the limit, not the printer. That is why the casual player's second printer slipped from day 3.4 to 4.4.
- **The starting design earns very little alone.** The free clips bring about £9 a day, so a new player has to buy designs straight away. Starting cash leaves about £125 after the first printer and spool, enough for four to eight designs.
- **Seasons are not applied.** Seasonal designs sell all year, and two of the best ten are seasonal (the Monster tooth necklace and the Heart lithophane).
- **The move to a small unit** (£399.99 and £9.99 a day) was priced before this pass. An attentive Standard player ends a week with about £470 in cash after the second printer.

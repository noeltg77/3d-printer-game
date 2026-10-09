# Balance notes: garage and small unit

Figures come from `scripts/dev/balance_report.gd`, which plays the game many times with a scripted player using the real rules: a week in the garage, then four weeks that carry on into the small unit. Re-run it after changing any number in `data/`:

```
godot --headless --path . --script res://scripts/dev/balance_report.gd
godot --headless --path . --script res://scripts/dev/balance_report.gd -- --part=garage    # or --part=unit: one half only
```

The small unit half is the slow one and takes several minutes. `--runs`, `--days`, `--unit-runs` and `--unit-days` change how much is played.

It is a model, not a playtest. The character is one pair of hands with rough job times (22 game minutes to collect and restart a print, 20 to pack an order) and prices everything at its typical price. It says nothing about whether the game feels good.

The catalogue is far bigger than a garage can print, so the scripted player does not buy every design. They buy the one that earns most for the time it takes (printer time plus their own), then the next, until expected orders would fill 80% of the printers' day or all of the character's. Once it is the printers that are full, they save for another one, and when the room has no space for another, for the move. Once it is the character who is full, they trade up: a listing that earns a quarter more a sale takes the place of the worst one they have. Add `-- --designs=all` to list every design instead of the summary.

## Targets

- A second printer is affordable in about 30 minutes of play at 1x (three game days). From the Phase 3 "done when".
- Problems are noticeable but not constant: a failure every 10 to 15 minutes of play, not every print.
- Each preset is a real choice: Draft tempting but costly, Standard the safe default, Strong worth it in some situation.
- A player doing everything sensibly is never penalised by the seller rating.

## Where the garage stands (200 runs of 7 game days, last run 2026-10-09)

| Player | Second printer | Worth after 7 days | Sold a day | Printer busy | Designs owned | Ruined | Flawed | Refunded | Rating | Effect on orders |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Attentive, Standard | day 2.4 | £844 | 18.1 | 83% | 16 | 2.3% | 1.6% | 3.3% | 4.34 | x1.07 |
| Casual, Standard | day 4.4 | £509 | 11.4 | 58% | 16 | 2.4% | 1.6% | 3.4% | 4.32 | x1.06 |
| Attentive, Draft | day 2.4 | £497 | 11.8 | 39% | 16 | 3.2% | 2.7% | 11.4% | 3.17 | x0.45 |
| Attentive, Strong | day 3.4 | £651 | 14.3 | 90% | 16 | 1.9% | 1.5% | 0.4% | 4.56 | x1.17 |

"Attentive" notices a printer needs them within 10 game minutes, "casual" within an hour. Day 2.4 is 24 minutes at 1x. The day always ends in .4 because money only arrives when the courier calls at 17:00. "Printer busy" is across both printers once the second arrives.

- **Second printer:** on target for an attentive player at 24 minutes. A casual one takes 44, with the quickest runs at 34; it was 34 with the old five designs.
- **Failures:** about one print in 25 goes wrong on a fresh Plodder Mini, roughly one every game day and a half. On target.
- **Wear:** still only the nozzle wears out inside a week. Spares cost £5 to £10.
- **Rating:** a careful Standard player still gains a little from it (x1.07).

Worth and sales are up to 15% higher than the last run of this table (£785, £441, £492 and £605). No number in `data/` changed: the scripted player got less wasteful when the report was extended. Two printers no longer start the same print for one order, and nothing is printed ahead once the shelves are full. The day the second printer arrives did not move.

## Re-run after the whole catalogue came in

The table above was first measured with only the 160 Garage designs in the game. It was run again once the Spare room and Workshop products were imported (635 in all) and every figure came out the same. That is expected, and worth knowing why:

- The scripted player only chooses from designs on sale in the garage. The 475 for later tiers are held back in the game too, so they change nothing here.
- The import did not alter any Garage product's numbers. Three were renamed, and that is all.

So the garage is where the last pass left it.

## The small unit (40 runs of 28 game days, last run 2026-10-09)

The same player, carrying on. When both garage spots are full and orders would fill them, they save for the move (£399.99), then pay £9.99 rent each midnight, list on Biddle as well as Craftsy, choose from the Small unit designs too and fill the unit's four printer spots. "Fast printers" means every printer after the first is a Zippy A1 Mini (£268.99, 2.2 times the speed) and not another Plodder Mini (£158.99).

| Player | Second printer | Moved | Third printer | Fourth printer | Worth after 28 days | Gaining a day, last week | Sold a day | Printer busy | Sales on Biddle |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Attentive, starter printers | day 2.4 | day 6.4 | day 7.4 | day 10.4 | £4,944 | £261 | 23.1 | 74% | 18% |
| Attentive, fast printers | day 3.4 | day 8.4 | day 10.4 | day 13.4 | £5,223 | £350 | 19.8 | 66% | 14% |
| Casual, starter printers | day 4.4 | day 8.4 | day 10.4 | day 13.4 | £3,860 | £240 | 19.2 | 66% | 21% |
| Attentive, stays in the garage | day 2.4 | never | | | £4,452 | £163 | 23.6 | 85% | |

Worth is cash plus what the printers cost. The cost of the move and the licences are spent and not counted.

- **The move comes after about an hour of play** (day 6.4) for an attentive player and 84 minutes for a casual one. Every run got there.
- **It pays, slowly.** The player who moves is gaining £261 a day by the last week against £163 for the one who stayed, and is £490 ahead after four weeks. Until then they are paying off the move, two printers and about eighteen more licences.
- **The rent hardly registers.** £9.99 is 4% of what a day in the unit earns. Before the move the same player was gaining £87 a day in the garage; after it, £206 with the rent paid.
- **The character is the limit, not the room.** Sales a day do not go up after the move (23 either way): one pair of hands packs about that many. The gain comes from selling dearer things. The player trades up nineteen listings and ends with the same eighteen or so on sale, and the printers are busy only 74% of the time. Four spots are worth having for the longer prints, not for more of them.
- **Silk PLA is what the unit is for.** It is 40% of sales from 40 designs, because its jewellery and props earn £4.55 an hour in the middle of the range against £2.63 for Garage PLA. PETG is 194 designs and 5% of sales: the middle one earns £2.72, no better than what the player already owns. TPU sold nothing, even to the player with direct drive printers (£2.48).
- **Biddle is a sideline.** 14 to 21% of sales. The same design earns about a quarter less a sale there (lower price, higher fee), so with no time to spare it only wins a place for the best designs. Its rating settles lower (4.0 to 4.1 against 4.3 to 4.4), which costs a casual player 4% of orders there and an attentive one nothing.
- **Fast printers are the better buy, later.** They put the move back two days and end £280 ahead, gaining £89 a day more: shorter prints fit more of the long, dear designs into a day and wear out fewer parts (£185 against £318).
- **Parts add up.** Four starter printers go through 43 parts in four weeks, about £11 a day. Still no breakdowns for a player who replaces worn parts.

## What the report does not cover

The rules below are in the game but not in the model.

- **Trends.** Every three to five days one category sells at 1.8 times its usual rate and another at 0.6. A player whose designs lean on the cool category will earn less than the table says, and one who chases the hot one more. Seasonal categories are left out of trends, and seasons themselves are still not applied.
- **Damp filament.** PLA takes five game days in the open to get wet, and a busy garage empties a spool in a day or two, so it should hardly matter in the first week. It matters for a slow starter, and for PETG and TPU later.
- **Printer upgrades.** None is bought, so nothing prints in more than one colour. That leaves out all 168 multicolour Small unit designs.
- **Gritty filament.** Glow, Wood and Carbon PLA wear a brass nozzle out in a few prints, and the player never fits a hardened one, so those 20 designs are left out as well. In a short trial with them in, printers broke down several times a game.
- **Printing several to a bed.** Each print is one item. Batches would save the character's time, which is the limit in the unit, so the unit may be worth more than the table says to a player who uses them.
- **Pricing.** Everything is listed at the typical price for the marketplace. Raising prices to thin out orders is the other answer to a full day.
- **The workshop and staff.** The long game stops at the small unit. A second pair of hands is what would lift the limit found above.

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

- **Draft costs a lot.** It ends the week 41% behind Standard, with orders at less than half. The second printer still arrives just as fast, so the cost comes later.
- **Strong is a real choice again, but a costly one.** It ends 23% behind Standard and buys the second printer a day later, for almost no refunds and the best rating. With one printer its longer prints are what hold it back.
- **A casual player's printers sit idle over 40% of the time.** With sixteen designs of mostly small prints, the character's attention is the limit, not the printer. That is why the casual player's second printer slipped from day 3.4 to 4.4.
- **The starting design earns very little alone.** The free clips bring about £9 a day, so a new player has to buy designs straight away. Starting cash leaves about £125 after the first printer and spool, enough for four to eight designs.
- **Seasons are not applied.** Seasonal designs sell all year, and two of the best ten are seasonal (the Monster tooth necklace and the Heart lithophane).
- **The move to a small unit** (£399.99 and £9.99 a day) is covered above. The rent could be several times higher and still be paid easily; whether it should be depends on how soon staff arrive to lift the limit on the character.
- **PETG and TPU earn too little to be chosen.** Between them they are 227 of the 274 single colour Small unit designs the player could buy. Their prices come from the catalogue; their demand and fees from the same placeholder rules as the garage's.

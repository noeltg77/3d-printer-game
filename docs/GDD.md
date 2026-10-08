# Print Shop Tycoon: Game Design Doc

Oct 8, 2026 · @Noel Tovey-Grindlay

## 1. Overview

A cosy isometric 3D printing business sim with a proper tycoon brain underneath. You start in a garage with one cheap printer and grow into a factory taking 1,000-unit B2B orders.

**Working title:** Print Shop Tycoon (placeholder)

**Pitch:** Turn a garage hobby into a manufacturing empire. Print, sell, fix, upgrade, repeat.

### Pillars

- **Cosy on the surface:** warm low poly visuals, a little character pottering between printers and shelves, satisfying print animations.
- **Deep on the business side:** real costs, margins, stock, reviews, refunds, cashflow and capacity planning.
- **Beginner friendly:** you should never need to own a printer to understand it. Real printer owners should still laugh in recognition.
- **Things go wrong:** failed prints, worn parts and damaged deliveries are core to the fun, not a punishment.

### Key decisions so far

| Area | Decision |
| --- | --- |
| Tone | Cosy theme and visuals, deep tycoon mechanics |
| Perspective | Static isometric view, character moves around the space |
| Mode | Sandbox with milestones, no story campaign for now |
| Design work | No minigame. Character sits at the PC for a set time to create their own version of an existing item |
| Business UI | An in-game computer is the hub for all business screens |
| Slicing | Simplified presets with a risk meter, not a full slicer |
| Printer building | Out of scope. No custom printer assembly |
| Brands | Parody names only, no real brands (e.g. no Bambu Lab) |

## 2. Art direction and tech

Low poly, flat shaded, warm and cosy, built mostly from procedural assets generated with Claude Code.

### Look and feel

- Faceted low poly geometry with flat shading, chunky readable silhouettes.
- Small fixed colour palette (palette texture or vertex colours) so everything matches.
- Soft shadows, ambient occlusion and warm colour grading do a lot of the heavy lifting.
- Fixed isometric camera with zoom. Interiors use cutaway walls so you can see inside.
- Reference vibe: low poly diorama tiles and cosy village scenes (the two reference images shared).

### Characters

- Segmented characters (separate body, head, arms, legs on pivots), no skinned meshes to start.
- Simple procedural animation: walk cycle from sine waves, body bob, reach and place.
- Carry and place items by attaching them to a hand socket.
- Fallback if needed: auto-rig via Mixamo or use a CC0 low poly pack as a base.

### Procedural asset approach

- **Blender + Python (bpy), run headless:** Claude Code writes seeded generator scripts, exports .glb, renders preview images and checks them. This preview loop is the key part.
- One generator per asset family: printers, filament spools, shelves, desks, PC, boxes, character parts, props.
- Every generator takes a seed and parameters (size, colour, variant) so we get variety for free.
- Hand polish only for hero assets if needed.

### Engine

- **Godot 4** recommended: free, lightweight, great for isometric 3D, already used for the landlord sim so economy and UI patterns can carry over.
- GDScript for gameplay, data driven content (printers, filaments, products) in JSON or Godot resources so balancing doesn't need code changes.
- Target: Steam, PC first.

## 3. Core loop and progression

The whole game hangs off one loop. Every later system adds depth to a step in it rather than adding a new loop.

### Core loop

1. **Get a design:** buy a licence or design your own at the PC.
2. **Check materials:** enough filament in the right type and colours? If not, order it and wait for delivery.
3. **Pick printer and preset:** Draft / Standard / Strong, with the risk meter.
4. **Print:** character loads filament, starts the job, collects the plate. Prints can fail.
5. **Post-process and pack:** remove supports, light finishing, box it up.
6. **List and sell:** marketplaces, own shop, or fulfil an order.
7. **Deal with the fallout:** reviews, returns, refunds, damaged deliveries.
8. **Reinvest:** spares, upgrades, new printers, more space, staff. Back to step 1.

### Progression tiers

| Tier | Space | Kit | New systems unlocked |
| --- | --- | --- | --- |
| 1. Garage | Single garage | 1 cheap printer, PLA only | Buying designs, one marketplace, filament ordering, failures, basic maintenance |
| 2. Spare room / small unit | Room for 3 to 5 printers | Upgrades: hardened nozzles, enclosure, filament dryer, multicolour unit | Own designs, more filaments, more marketplaces, reviews matter |
| 3. Workshop | Rented unit | Small print farm, linked multicolour units | First hire, stock management, first B2B enquiries |
| 4. Factory | Industrial unit | Dozens of printers, later resin / SLS / industrial machines | Staff teams, bulk contracts, automation, supplier deals, optional injection moulding endgame |

Your character shifts from **maker** (does everything by hand in the garage) to **manager** (hires staff and buys automation) as the business grows.

## 4. Game systems

Each system below is designed to plug into the core loop. Numbers are placeholders for balancing later.

### 4.1 Printers

- Stats: print speed, build volume, reliability, supported filaments, max nozzle temp, enclosure yes/no.
- Tiers from cheap open-frame bed slinger up to fast enclosed core XY machines, then resin, SLS and industrial later.
- Printers run while the character does other things, including overnight.

### 4.2 Upgrades and parts

- Nozzles: brass (standard), hardened steel (abrasives), larger diameters (faster, less detail).
- Enclosure (needed for ABS/ASA), filament dryer, auto bed levelling, plate auto-eject (late game automation).
- Upgrades both unlock capabilities and reduce specific failure types.

### 4.3 Filaments

| Filament | Unlocks | Quirks | Needs |
| --- | --- | --- | --- |
| PLA | Basics, decor, organisers | Easy, cheap | Nothing |
| PETG | Tougher functional parts | Stringing | Nothing |
| TPU | Soft and rubbery items: phone cases, grips, feet | Slow, jams in multicolour units | Direct drive friendly printer |
| ABS / ASA | Outdoor and heat resistant parts | Warping | Enclosure |
| Carbon fibre blends | Strong premium parts | Eats brass nozzles | Hardened nozzle |
| Silk, glow, wood | Premium cosmetic items | Pricier | Nothing |

- Filament absorbs moisture over time if stored badly, raising failure rate until dried.
- Spools are physical items on shelves. Running out mid-print is a real risk.

### 4.4 Multicolour units (AMS style)

- Each unit holds 4 spools. Link units together as an upgrade for more colours (e.g. 2 units = 8 colours).
- **Colour change waste:** every swap purges filament. Dark to light swaps waste more.
- Multicolour prints sell for more but cost more in waste and time.
- Grouping colours and batching jobs to cut swaps is a light optimisation puzzle.
- Waste is tracked and shows up in costs (stretch: sell or recycle waste later).

### 4.5 Print settings (simplified slicing)

- Presets: **Draft / Standard / Strong**, plus toggles like supports and multicolour.
- A simple risk meter shows chance of failure and durability.
- Skimping on infill lowers a hidden **durability** stat: more fails, items crushed in delivery, refunds and bad reviews.
- Players learn by consequences, no jargon needed.

### 4.6 Print failures

- Spaghetti, warping, poor bed adhesion, clogs, layer shifts, wet filament, run out of filament.
- Chance driven by printer reliability, part wear, filament condition, preset and design difficulty.
- Failed prints waste filament and time, and are visible in the scene (a tangled mess on the plate).

### 4.7 Maintenance and wear

- Parts wear individually: nozzle, hotend, build plate, belts, PTFE tube, fans.
- Abrasive filaments speed up nozzle wear.
- Worn parts raise failure chance. Eventually they break and the printer stops.
- Fix by buying a replacement (wait for delivery) or keeping spares on the shelf. Upgrade the part to stop it recurring.
- Late game: maintenance staff and a maintenance schedule screen.

### 4.8 Designing your own products

- No minigame. The character sits at the PC for a set time to create their own version of an existing item type (e.g. their own desk organiser).
- Own designs: no licence fees, better margins, but cost time.
- Bought designs: instant, but come with fees, royalties or personal use only restrictions.
- Design quality improves with iterations (V1, V2, V3) and the character's design skill.
- Optional test print before launch. Skipping it risks a dud listing.

### 4.9 The computer (business hub)

All business screens live on an in-game PC. The character walks to it to use it.

- Design catalogue and own design projects.
- Supplier shop: filament, parts, upgrades, printers, packaging. Orders arrive as deliveries.
- Marketplace listings and orders.
- B2B contract inbox.
- Bank: cash, costs, loans.
- Analytics: sales, margins, failure rates, reviews.
- Flow example: pick a design, it checks filament needed vs stock, prompts you to order more if short.

### 4.10 Selling and marketplaces

- Parody marketplaces modelled on Etsy, eBay and Amazon style platforms, plus later your own web shop and craft fairs.
- Each has fees, audience, price expectations, review systems and rules.
- Demand and trends: categories rise and fall (fidget toys, cosplay, wargaming terrain, home organisation).
- Shipping and packaging costs, delivery damage, returns and refunds.
- Seller rating affects visibility and sales.

### 4.11 B2B contracts

- Mid to late game. Clients send requests: "Print 1,000 of these by Friday".
- Each contract has specs: material, colour, quantity, quality bar, deadline, price, late penalties.
- Types: prototyping, replacement parts, event merch, props.
- Capacity planning becomes the main puzzle. Risk of clients paying late or going bust.

### 4.12 Stock and inventory

- Filament, spare parts, packaging and finished goods all physically stored on shelves.
- Reorder points, supplier lead times and bulk discounts.
- Storage space is limited and drives the move to bigger premises.

### 4.13 Staff and automation

- Roles: print operator, post-processing, packer, maintenance tech, designer.
- Wages, skill levels, simple scheduling.
- Automation upgrades (auto-eject plates, conveyors) reduce staff load.

### 4.14 Money

- Cash, costs per print (filament, waste, electricity, packaging, fees, shipping), rent, wages, loans.
- Clear per-product margin view so players learn what actually makes money.

### 4.15 Events

- Viral spike on a product, competitor undercutting, filament shortage or price hike, a big client going bust, power cut mid-print.

### 4.16 Sandbox goals

- No campaign. Milestones give direction: first sale, first £1k month, first 5-star streak, first B2B order, first 1,000-unit contract, move to a unit, first hire.
- Stretch: scenario starts later (e.g. inherit a failing print farm).

## 5. Phased build plan

Build small and prove each step before moving on: assets and garage first, then one working loop, then layer systems on top. Don't start a phase until the previous one hits its done criteria.

### Phase 0: Project setup

- [x] Godot 4 project, folder structure, git repo
- [ ] Blender headless pipeline: generator script runs, exports .glb, renders a preview PNG
- [x] Shared palette texture and flat shaded material
- [x] CLAUDE.md with conventions (see section 6) and this doc in the repo
- [x] Data schemas drafted for printers, filaments, products (JSON or Godot resources)

**Done when:** one test asset is generated, previewed, imported into Godot and looks right with the palette.

### Phase 1: Asset prototyping

- [ ] Printer generator: 2 to 3 models (cheap open frame, mid enclosed, multicolour unit)
- [ ] Filament spool generator (colour as a parameter)
- [ ] Garage shell: walls, floor, roller door, window, lighting
- [ ] Props: shelving, workbench, desk, PC, chair, boxes, bins
- [ ] Segmented character: body parts on pivots, a few colour variants
- [ ] Animations: idle, walk, carry, reach and place, sit at PC

**Done when:** everything sits together in one garage scene and looks cohesive and cosy.

### Phase 2: Garage scene and character control

- [ ] Isometric camera with zoom, cutaway walls
- [ ] Click to move with navigation, character avoids props
- [ ] Interactables: printer, shelf, PC, workbench, door
- [ ] Carry system: pick up a spool, load it into the printer, collect a finished item, place it on a shelf
- [ ] Fake print: timer, simple build-up animation on the plate

**Done when:** you can walk to the shelf, grab a spool, load the printer, start a print, collect the result and shelve it. No economy yet.

### Phase 3: First playable loop (MVP)

- [ ] Game time with speed controls (pause, 1x, 2x, 4x)
- [ ] One printer, PLA only, a handful of bought designs
- [ ] Filament stock tracking, usage per print
- [ ] PC hub v1: design catalogue, supplier shop with deliveries, one marketplace, bank
- [ ] Selling: list items, orders come in, pack and ship
- [ ] Basic economy: costs, prices, cash

**Done when:** a 30 minute session lets you earn enough to buy a second printer and it feels good doing it.

### Phase 4: Things go wrong

- [ ] Print presets (Draft / Standard / Strong) with risk meter
- [ ] Print failures with visible results
- [ ] Part wear, breakdowns, replacements, spares on shelves
- [ ] Durability stat, delivery damage, returns, refunds, reviews, seller rating

**Done when:** problems feel fair and funny, not frustrating, and upgrades clearly reduce them.

### Phase 5: Vertical slice polish

- [ ] Save and load
- [ ] UI polish, sound effects, music, lighting pass
- [ ] Light onboarding hints for non printer owners
- [ ] Balance pass on the garage tier
- [ ] Playtest with printer owners and complete beginners

**Done when:** the garage tier is a shareable demo you'd be happy to show people.

### Phase 6: Tier 2 expansion

- [ ] More printers and upgrades (hardened nozzle, enclosure, dryer, auto levelling)
- [ ] PETG, TPU, ABS/ASA, carbon fibre, silk/glow/wood
- [ ] Filament moisture and drying
- [ ] Own designs at the PC with iterations and test prints
- [ ] More marketplaces, trends and demand
- [ ] Move to a bigger space

### Phase 7: Multicolour units

- [ ] Multicolour unit with 4 slots, linkable units
- [ ] Colour change waste, batching to reduce swaps
- [ ] Multicolour products and pricing

### Phase 8: Tier 3 workshop

- [ ] Rented unit, print farm layout
- [ ] Staff: hiring, wages, roles, simple scheduling
- [ ] Stock management, reorder points, supplier lead times
- [ ] B2B contract inbox, specs, deadlines, penalties

### Phase 9: Tier 4 factory

- [ ] Industrial unit, larger farms, automation (auto-eject, conveyors)
- [ ] Resin, SLS and industrial machines
- [ ] Large contracts, events, milestones
- [ ] Optional injection moulding endgame

### Phase 10: Release

- [ ] Steam store page and trailer
- [ ] Public demo (garage tier), aim for a Steam Next Fest
- [ ] Early access, then iterate on feedback

## 6. Notes for Claude Code

Put this doc in the repo (export as Markdown, e.g. `docs/GDD.md`) and point CLAUDE.md at it as the source of truth.

### Working rules

- Work one phase at a time. Each phase gets its own branch and its own session, referencing the matching section here.
- Don't build systems from later phases early. Stub them if needed.
- Content is data driven: printers, filaments, parts, products, marketplaces and contracts live in data files, not hard coded.
- Asset generators are seeded, parameterised Blender Python scripts in `tools/generators/`, one per asset family. Always render a preview and check it before importing.
- All assets use the shared palette and flat shaded material.
- Keep simulation logic (economy, wear, failures) separate from visuals so it can be unit tested and balanced on its own.
- Parody names only for brands and marketplaces.
- Update the checkboxes in section 5 as tasks land.

### Suggested repo layout

- `docs/` this GDD and any balancing notes
- `tools/generators/` Blender Python asset generators
- `assets/` generated .glb files, palette, materials
- `data/` printers, filaments, parts, products, marketplaces
- `scenes/` garage and later premises
- `scripts/` gameplay code: character, interactables, printing, economy, UI

## 7. Open questions

- [ ] Final game name
- [ ] Currency and setting: UK based (GBP) or neutral?
- [ ] Time scale: how long is an in-game day, and how long does a typical print take in real time?
- [ ] Character: customisable or a fixed character?
- [ ] Exact colour palette and mood board
- [ ] Price point and whether to do a free demo first
- [ ] Controller support or mouse and keyboard only?

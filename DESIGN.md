# Parcel Pack

Native SwiftUI shipping tycoon for iPhone, iOS 17+, and macOS. Fixed parcels throughout, no rotation. One playable business with bottom tabs **Pack / Orders / Crew / Depot / World**. Preserve the warm cardboard palette, rounded native typography, parcel tape seams, and miniature isometric shipping floor. DESIGN_VARIANCE=6 MOTION_INTENSITY=3 VISUAL_DENSITY=3.

Signature: a warm cardboard grid filled with saturated parcel tiles, tied to a miniature working depot. Native SF Rounded numerals; native supporting text for readability and Dynamic Type. Type scale 14/16/20/28/36 points. Four-point spacing base, 12- and 24-point container radii; tile corners scale with cells. One soft shadow on lifted parcels. Native SF Symbols supply UI iconography.

Palette roles: background #F8F4EC, surface #FFFCF6, foreground #253D38, muted #5D7068, cardboard #E3D4BD, grid #D1BEA0, accent #267B61, accent foreground #FFFFFF. Parcel fills #D98765, #E5B74C, #70A69C, #8F9FC3, #A0AE77, #CB8EAD. Invalid placement includes a red outline and unavailable icon. Material tones inside Canvas are illustration shading tied to the existing palette. A light color scheme preserves legibility.

## Business loop

Pack → customer trust → contracts → equipment milestones → neighborhoods → franchise. Keep the next useful action visible. The wallet stays visible across tabs. Pack centers the box, customer, projected pay, and dispatch/contract progress; Undo/Hint/Ship remain reachable. Choosing another customer requires confirmation for a partial box. Shipping and the next order retain the chosen customer. Visiting a neighborhood changes the business context without discarding that box. Historical receipts retain their actual payout after purchases or relationship changes.

Eight original customers plus Harbor Outfitters, Gallery Store, and Uptown Boutique. Five main depot stages and six equipment lines with 30 levels. Workbench/shelves/labels add $8/$4/$6 per level; vans add 10% per level; conveyor and dispatch improve crew speed/pay. Milestones at levels 5/10/20/30 add 10% per milestone to their relevant pay/speed channel and change equipment titles and scene fittings. Expansion gates remain $650/7 deliveries, $2,500/25, $9,000/65, and $25,000/130. Automatic shipments count toward growth.

## Active and automatic work

Manual clean packing adds 20% of customer base pay; hints remove only this bonus. A manual shipment earns three relationship XP and two stored dispatch boosts, capped at 120. A boost adds 20% to a future crew delivery and consumes one charge, so short visits remain useful without a wall-clock deadline. Five trust ranks at 10/30/75/150/300 XP give +3% pay each and persist across franchises.

Nine customers support up to 20 workers and one manager per team: the first six original stores plus the three district customers. Every team ships directly to cash with no collection or holding-area bottleneck. Base interval is 120 seconds, divided by extra-worker, conveyor, manager, training, milestone, and specialty bonuses. Managers give +25% speed and +25% pay. Managed teams can switch freely between General, Express (+15% speed), Careful (+15% pay), and Mentor (two relationship XP per automatic shipment). Crew displays actual pay, timing, progress, prices, and requirements. Income feedback stays separate from manual packing announcements.

Offline catchup is eight hours plus two per Logistics level, to eighteen hours. Production events process chronologically, including relationship thresholds, finite boost stock, and contract completion. Satellite branches operate on their own 60-second cycles alongside all owned crews. No offline batch automatically accepts another contract.

## Contracts

One active contract. Three deterministic offers change after a completion; available customers follow the current district and unlocks. Supply contracts count subsequent matching manual and crew shipments. Premium and landmark contracts count manual shipments. Premium rewards cash, twelve boost charges, and one blueprint; each blueprint adds 2% manual pay, capped at ten. Landmark contracts become available at Shipping hub and qualify the current business for franchising. Jobs have no deadline. Rewards, completion records, XP, and shipping pay commit atomically, once. The latest completed job remains a receipt. Accepting a contract does not replace the current box; Pack contract uses normal customer selection and partial-box confirmation.

## Neighborhoods

Old Town contains the original depot and stores. Harbor/Arts Quarter/Uptown require one/two/three completed franchises. At Shipping hub, open branches for $15,000/$25,000/$40,000, respectively. Each branch has ten levels, an independent production fraction, and a new local customer. Opening or upgrading a branch spends cash; all owned sites keep earning when another district is visited. World gives a concrete locked/open/owned state, actual income, and meaningful branch actions. The depot artwork reflects district signage and equipment.

## Franchising

Voluntary prestige requires Shipping hub and one completed landmark contract. Stars are 3 + floor(sqrt(total run earnings / 10,000)) + two per completed landmark. Spending cash does not lower the reward. Display current reward and earnings needed for the next star. The confirmation previews the exact reset and preserved values; requesting or cancelling it never resets the business.

Reset current cash, main building, equipment, crew, branch sites, current contracts, manual boosts, order sequence, and box. Preserve trust, blueprints, lifetime shipment/contract/earning records, stars, Head Office, and unlocked district access. Use a fresh seed and a new Corner Market session. Account/session/clock reset in one saved snapshot; old orders cannot be redeemed in the new business. Established Business provides its starter grant and worker on the next franchise.

Five Head Office lines have five levels and next-level star costs 1...5: Training (+10% crew speed and +5% branch pay/level), Buying Power (-5% equipment price/level), Premium Service (+10% manual pay/level), Established Business ($250/level and first worker next run), Logistics (+2 offline hours/level). Starting grants are supported explicitly by account validation and excluded from lifetime earned revenue.

## Persistence and interaction

Cash, progression, staff, branches, box, receipt, and production timestamp share one validated snapshot. Settle elapsed work at previous levels before any purchase, specialty change, contract acceptance, or prestige. Retain fractional work, discard production beyond business limits, and never move the clock watermark backward. Manual sequences remain independent of automatic deliveries. New fields decode with defaults; keep old business values and historical receipts. Seed lifetime totals from prior aggregate records, never fabricate historic per-customer XP. Legacy waiting orders pay their saved value once on launch.

Free Play and Shift are absent from navigation and app lifecycle. Retain their historical save keys and shared core/helpers/tests. No new deadline, lives, ads, real-money purchases, network, or account flow.

Dragging shows a ghost at the actual final placement rectangle. Select-and-tap and VoiceOver board labels provide alternatives. Controls target 44 points; content scrolls for enlarged text. Respect Reduce Motion. Sound and haptics use existing preferences. Inspect native 375-point Mac and iPhone portrait renders, saves, contracts, staff income, and voluntary reset before shipping; evidence lives in VALIDATION.md.

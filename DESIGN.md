# Parcel Pack

Native SwiftUI packing game for iPhone, iOS 17+, and macOS. Two playable modes: **Tycoon** and **Free play**. Fixed blocks throughout; no rotation. Preserve the warm cardboard palette, rounded native typography, and parcel tape seams. DESIGN_VARIANCE=6 MOTION_INTENSITY=3 VISUAL_DENSITY=3.

Signature: a warm cardboard grid filled with saturated parcel tiles. Native SF Rounded numerals; supporting copy uses native text. Type scale 14/16/20/28/36 points. Four-point spacing base, 12- and 24-point container radii; tile corners scale with cells. One soft shadow on lifted parcels.

Palette roles: background #F8F4EC, surface #FFFCF6, foreground #253D38, muted #5D7068, cardboard #E3D4BD, grid #D1BEA0, accent #267B61, accent foreground #FFFFFF. Parcel fills #D98765, #E5B74C, #70A69C, #8F9FC3, #A0AE77, #CB8EAD. Invalid placement includes a red outline and an unavailable icon. A light color scheme preserves legibility.

## Tycoon

Bottom tabs **Pack / Orders / Crew / Depot**. The wallet stays visible across tabs. Pack keeps the box central, with the customer and projected payment above and Undo/Hint/Ship below. The next order retains the selected customer; explicit switching requires confirmation for a partial box. Orders provides direct access to each unlocked store as well as generated offers. Paid receipts retain the historical payout after purchases.

Eight customers, five depot stages, six equipment lines with 30 levels each. Workbench/shelves/labels add $8/$4/$6 per level. Vans add 10% per level to base plus equipment. A clean manual pack adds 20% of base pay; free hints remove only that bonus. Expansion gates remain $650/7 deliveries, $2,500/25, $9,000/65, and $25,000/130. Automatic staff deliveries also count.

Six smaller clients support worker teams of up to 20 workers and one manager each. Every team continuously ships directly into cash; there is no collection button or three-order production limit. Base interval is 120 seconds, divided by (1 + 0.15 × extra workers) and (1 + 0.05 × conveyor level), then by 1.25 for a manager. Worker pay is half of base plus packing equipment with van and dispatch multipliers; managers add 25% to that rounded payout. Dispatch adds 5% per level. Closed-app catchup caps at eight hours for all teams. Crew shows exact pay, timing, progress, prices, and remaining requirements. Automatic income feedback does not interrupt manual packing announcements.

Depot is a miniature shipping floor drawn in a native Canvas from saved building, equipment, and staff. Storage, packing, dispatch, and loading areas have clearer visual roles, with wall signage, fuller shelves, floor markings, and softer material shadows. Owned equipment changes the scene; workers and managers appear at their stations. A compact workforce and automatic-income band accompanies the scene. Purchase rows show price and actual benefit. No real-time manual deadline, ads, lives, real-money purchases, or server dependency.

Cash, staff state, active box, receipt, and production timestamp share one validated snapshot. Settle elapsed work at prior equipment/team levels before a purchase. Keep fractional progress and discard time beyond a business limit. Never move the production timestamp backward. Manual order sequences and receipts are independent of automatic deliveries. Version 1 saves decode new fields with defaults. Legacy waiting orders are paid once on launch, even if no time has elapsed; their saved payout is retained.

## Endless Free play

An 8×8 board is the focal point, with current/best score and a three-piece tray. Board targets are at least 44 points at 375-point width. Each fixed piece scores 10 per square; full rows and columns clear simultaneously for 100 per line. Refill only after all three pieces are placed. Game over means no remaining piece fits. New game asks before discarding an active run; best score is retained. A hint marks a legal top-left square without moving pieces or scoring.

Persist the board, tray, RNG, placement/line counters, score, and best in a separate save. Validate their relationships before restoring; a malformed run must not erase a valid record. Old Shift and Free pack saves remain untouched, but their gameplay is removed from navigation and app lifecycle.

## Interaction

Dragging shows a ghost using the exact final placement rectangle. Select-and-tap and VoiceOver board labels provide alternatives. Respect Reduce Motion and use scrolling for enlarged text. Sound and haptics use the existing preferences. Native compact renders, save migration, once-only automation, line clears, and phone installation are recorded in VALIDATION.md.

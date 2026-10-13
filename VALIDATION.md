# Parcel Pack validation

Date: October 13, 2026 (America/New_York). Current version: **1.2, build 3**.

## Builds and tests

- **95 Swift tests pass**: 64 core tests in nine suites, 31 app-model tests in six suites. Swift 6.4, Xcode 27.0 (27A266a).
- Native Mac release packaging succeeds. The build script uses SwiftPM's actual binary path rather than copying an earlier binary.
- The shared Xcode scheme builds successfully for generic iOS Simulator with signing disabled and for a signed generic iOS device. iOS deployment target remains 17.0. All 20 shared Swift source files compile.
- `codesign --verify --deep --strict` passes for the signed iPhone artifact. Device Control installed and launched version 1.2/build 3 on the user's iPhone 15 running iOS 26.7.1; a filtered app listing confirms both numbers.
- Personal signing settings remain local. The canonical Git project leaves the development team empty; regeneration retains the local team.

## Tycoon and staff

- Deterministic exact-fill orders cover all eight customers with fixed orientations. Shipping pays only a complete current order and cannot repay its receipt. Hints remove only the clean bonus. Purchases cannot overdraw cash and preserve the current box and historical receipt.
- Two 250-shipment simulations, one clean and one hinted, reach all five depot stages and all eight clients under the actual rules.
- Six equipment lines now support 30 levels; new label, conveyor, and dispatch effects are checked with the existing workbench/shelf/van effects.
- Staff tests cover worker costs/caps, unlocked customer requirements, the three-order unmanaged holding limit, fractional progress, manual collection, manager purchase collecting pending work once, automatic shipping, eight-hour catchup, and invalid/nonfinite elapsed time.
- Pending staff revenue reserves money and counter headroom. Manual payments cannot consume that reserved capacity. Invalid teams, money, counters, order seeds, and receipt history are rejected.
- Automatic deliveries never change the manual order sequence or last manual receipt. Collected staff deliveries count toward client unlocks and expansion requirements.
- Version 1 JSON with no staff fields retains the original cash, building, equipment, current customer, and box. Missing new equipment keys read as level 0. Broken nested boards retain a valid business within the 128 KB save limit.
- Model regression tests keep Circuit Supply selected over shipping, next order, and relaunch. Staff time settles at prior equipment levels before purchases. Income and its production timestamp save together, so relaunch cannot repeat catchup. A backward clock change and return to the prior timestamp produce no duplicate work, including the following half-interval.
- Independent integration review found and resolved the clock-watermark issue and occupied bounding-box anchor issue for fixed shapes with an empty top-left corner.

## Endless Free play

- 19 focused core/store/model tests cover generated fixed pieces, invalid placements without mutation, row and column clears, crossing lines counted once, tray refill after all three pieces, deterministic RNG continuation, score/counter accounting, and game-over legal-fit detection.
- Save checks retain the active board, tray, score, RNG, and best score. A malformed active run preserves a valid best. New game keeps the record and requires confirmation for a live run.
- Hint highlights a legal placement without awarding points or placing a piece. Occupied bounding-box anchors remain tappable when a shape's actual footprint fits around them.
- Shift is absent from the mode picker and app lifecycle. Previous Shift and exact-fill Free pack saves remain untouched; the endless run uses its own save key.

## Native play checks

- The Mac 375-point layout restores the pre-update Shopfront, $40 cash, workbench level 1, and paid bookshop box. Crew, customer catalog, all six upgrade rows, and Free play render without clipped controls; the wallet remains visible while depot content scrolls.
- Played eleven consecutive Little Leaf orders and two Circuit Supply orders through the native interface. Next order retained the customer each time, and the Circuit Supply label and payment stayed selected.
- Hired a Corner Market worker for $540 and its manager for $1,350. Observed progress advancing, automatic $49 revenue, and total delivery progress increasing independently of the manual order sequence.
- Bought the label printer for $140 and conveyor for $225. The account deducted the prices after settling older worker pay, and the scene and staff statistics reflected the new equipment. The depot draws the hired worker and manager.
- In Mac Free play, placed all three initial pieces, scored 90, and observed a new tray. New game requested confirmation; cancelling and relaunching retained score 90, the board, tray, and record.
- The iPhone 18 Pro simulator shows both modes in portrait with safe areas, the four Tycoon tabs, full 8×8 board, and visible tray/actions. Tap placement scored 40; dragging the second fixed shape scored another 30.
- Version 1.2/build 3 is installed and launched on the physical iPhone 15. Further physical finger, enlarged-text, audio, haptic, and VoiceOver checks remain. No IPA export, TestFlight upload, or App Store release has been made.

## Retained regression coverage

Legacy Shift tests still verify fixed-orientation generated plans, required parcels, shelf carryover, rush fees, best-full-box scoring, saved outcomes, overflow bounds, and old save migration. Original Free pack tests cover exact fills, hints, blocked-hint recovery, bounds/overlap, lifetime counts, and legacy orientation migration. These support shared packing helpers and preserved historical data; those modes are no longer selectable.

Work is backed up on `claude/optimistic-johnson-nmx2si`. Main is unchanged. Build products and orchestration logs remain ignored.

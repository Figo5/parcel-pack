# Parcel Pack validation

Date: October 12, 2026 (America/New_York).

## Builds and tests

- **41 tests pass** with Swift 6.4 in Xcode 27.0 (27A266a): 22 core tests and 19 app model tests.
- `zsh scripts/build-mac.sh` produces the current native release app. The script now resolves SwiftPM's actual binary directory, including Xcode 27's build layout, instead of potentially copying a stale binary.
- The ParcelPack Xcode scheme builds successfully for generic iOS Simulator, Debug, using SDK 27.0 with signing disabled. Both arm64 and x86_64 sources compile. The binary is also installed and running on an iPhone 18 Pro simulator with iOS 27.0 in Device Hub.
- The project includes all nine shared Swift source files, a shared scheme, and the existing 1024×1024 opaque app icon. iOS deployment target remains 17.0.

## Shift checks

- An independent brute-force oracle matches the value solver on 48 tiny-board cases, including required-parcel constraints; both oracle and solver use fixed orientations. Returned placements are checked for exact coverage and required IDs.
- 160 deterministic generated plans have five boxes, mixed parcel sizes, surplus parcels, unique IDs, rush deadlines, and valid reference tilings. Branching shapes occur. All reference placements use rotation zero. Paired legacy generation keeps the same IDs, parcel values, deadlines, origins, and targets, so migration preserves progression.
- 375 generated boxes solve exhaustively. Scores meet or exceed the reference packing value and agree with the reconstructed placements.
- Branch-and-bound combines the most constrained empty cell with an exact-area knapsack upper bound. The earlier rotation-enabled implementation was compared against its previous solver on 120 generated boxes: zero score mismatches and no capped searches; median time fell from approximately 26.3 ms to 0.22 ms in optimized local builds. Those historical timings describe that earlier sample on this Mac. The fixed-orientation balance sample below uses the current solver and rules.
- Capped searches return only a valid lower bound, and the interface omits the best-full-box coaching figure unless the search proves optimality.
- Tests cover invalid placement without mutation, shelf capacity and transfers, full-box doubling, sealing exactly once, ordinary carryover, early rush returns, due-box shelf removal and a single late fee, best-full scoring before expired parcels are removed, cleared/failed progression, and saved phases.
- Save tests reject damaged quotas, mismatched seeds, inconsistent outcomes, missing arrivals, and overflowing parcel values. A saved quota from the earlier tuning remains valid. Corrupt session data does not erase the separate record; a maximum finished-run counter cannot overflow. Six additional migration tests cover missing legacy markers, retained footprints, incompatible unpacking, preserved shelf/score/quota, sealed snapshots, completed outcomes, idempotent relaunches, and once-only shipment credit.

## Balance sample

The current fixed-orientation Swift engine played 1,000 independent shifts (5,000 boxes), 100 seeds per shift number. The reference strategy packs the generated core fill and keeps no shelf. The strong strategy chooses a best full box with or without mandatory due rush parcels, compares the immediate scores, and shelves valuable leftovers with future rush parcels first. All sampled solver searches finished exhaustively.

| Shift | Target / reference | Reference clears | Strong strategy clears |
| --- | --- | --- | --- |
| 1 | 80% | 100/100 | 100/100 |
| 2 | 95% | 78/100 | 100/100 |
| 3 | 105% | 0/100 | 100/100 |
| 4 | 115% | 0/100 | 91/100 |
| 5 | 120% | 0/100 | 72/100 |
| 6 | 125% | 0/100 | 43/100 |
| 7 | 130% | 0/100 | 11/100 |
| 8 | 130% | 0/100 | 13/100 |
| 9 | 130% | 0/100 | 15/100 |
| 10 | 130% | 0/100 | 11/100 |

These are independent shift samples, not continuous-run survival rates. The strong strategy is myopic and is not proof of a globally optimal score, universal quota reachability, or human difficulty. The first shift remains forgiving; later shifts reward choosing valuable parcels and managing carryover. Targets plateau at 130%; rush frequency and generated boxes continue varying. Reproduce with `scripts/measure-shift-balance.swift` using the README command.

## Native renders and play

- Before removing rotation, tested Shift select-and-tap, rejection near the board edge, valid placement, undo, rotation, and dragging the rotated parcel into its landing position. An invalid/outside drag leaves progress intact.
- Shelved and unshelved a parcel, relaunched with a rotated placed parcel and shelf intact, shipped a partial box, checked its score and coaching figure, then confirmed carryover into the next box.
- Switched to Free pack and confirmed the previous Large box and six shipped boxes remained intact, then switched back without losing the Shift run.
- Rendered at 430 points wide and at the 375-point minimum. Shift's Undo/Shelve and Seal controls remain anchored at the bottom while the tray scrolls. Board targets retain at least 44 points at the minimum width. The light palette keeps both mode labels readable regardless of system appearance.

- The rebuilt fixed-shape iPhone app renders in Device Hub with Undo/Shelve/Seal and no Rotate control. A completed first box and transition to box two were observed in the running simulator. Automated core/model checks verify fixed placements, hint completions, and score searches; physical finger behavior remains to be tested.

## Existing Free pack coverage

The original checks still pass: 180 generated puzzles across three sizes; 90 hint completion cases; blocked-hint recovery; rotations including extreme inputs; bounds, overlap, duplicate and unknown IDs; alternate tilings; undo/reset; saved box and settings; once-per-box shipment counting; and preservation of lifetime counts when session data is rejected. The original October 8 native play checks included drag cancellation, hints, size confirmation, and compact layout.

## Pending device checks

Xcode is installed and its license/setup is complete. The iOS 27.0 runtime is installed and the game runs on an iPhone 18 Pro simulator. Physical iPhone installation, real finger placement, additional phone sizes and accessibility settings, audio, and haptics remain unverified. No signed IPA, TestFlight upload, or App Store release has been made. Device signing requires the user's Apple Account/team in Xcode.

## Contributions

Claude authored the initial SwiftUI views and the first Shift implementation on `claude/optimistic-johnson-nmx2si`. Codex recovered those pushed changes and completed the solver, tuning, save guards, native UI adjustments, tests, and build integration on the same branch. Claude's uncommitted cloud reference files were not fully imported; the core tests and Swift balance script here were implemented locally. Main remains unchanged.

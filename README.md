# Parcel Pack

A native SwiftUI packing game for iPhone and Mac. Build a shipping business in **Tycoon**, play a scored **Shift** run, or relax with the original untimed **Free pack**. Boxes are generated on-device. No timer, ads, real-money purchases, accounts, or network dependency.

## Play

Drag a parcel into the cardboard box, or select it and tap the square for its top-left corner. Parcels stay in the orientation shown in the tray; place them without turning. Tap a packed parcel to remove it; **Undo** removes your last placement. Every fresh box has an exact fill, but Shift gives you more parcels than fit.

### Tycoon

- Fill customer boxes, then **Ship** to earn cash. Packing without hints adds a bonus worth 20% of the customer's base pay. Hints are always free; they keep the full base and equipment payout.
- Choose from three generated orders in **Orders**. Eight customers unlock through deliveries and depot growth, bringing larger boxes and better pay. Switching a partly packed order asks first.
- Invest in a **Workbench** (+$8 per level), **Storage shelves** (+$4 per level), and **Delivery van** (+10% per level on base and equipment pay). Each has 12 levels. Upgrades apply to future deliveries, including your current unpaid order.
- Grow from a **Spare room** through **Shopfront**, **Local depot**, and **Warehouse** to a **Shipping hub**. Expansions require both saved cash and completed deliveries; the depot scene changes with your building and equipment.
- Cash, equipment, active order, and paid receipt save together. A shipped box cannot pay twice, and a damaged board can be replaced while retaining a valid saved business. Shift and Free pack keep their separate progress.

This first tycoon pass focuses on packing and building the depot. Staff and idle income are future work.

### Shift

- Each parcel is worth 1–4 points. Pack any subset and **Seal & ship** when ready. A full box doubles the packed value.
- Keep up to three spare parcels on the **Shelf** for later boxes in the same shift. Unshelve them or pack directly from the shelf. Tray leftovers are returned when you seal.
- Rush deadlines count boxes, not seconds. Returning a rush parcel early or keeping it on the shelf through its due box costs five points. Ordinary returns have no fee.
- Meet the target across five boxes to clear the shift and continue the run. Later shifts ask for more valuable packing and better shelf choices. Missing the target ends the run.
- A shipped box shows its scoring breakdown and the best full-box value available before late fees. The shelf clears between shifts; your best run and current progress save locally.

### Free pack

Fit every parcel into the box. **Hint** places one parcel while keeping a route to completion; it can unpack blocking placements and explains the change. Choose Small (4×4), Medium (5×4), or Large (5×5), then move to another generated box after finishing. The existing box, settings, and shipped count stay saved separately from Shift. Older boxes migrate to fixed shapes, retaining compatible placements and returning incompatible ones to the tray. Earned counts and scores stay saved.

## Play on this Mac

```sh
zsh scripts/build-mac.sh
open "dist/Parcel Pack.app"
```

The build script packages the current SwiftPM release binary into a native app. There are no external package dependencies.

## Install on your iPhone

Open **ParcelPack.xcodeproj** and choose the shared **ParcelPack** scheme. The target supports iOS 17 or later; the current checkout has been compiled with Xcode 27.0, Swift 6.4, and the iOS Simulator 27.0 SDK.

1. Finish Xcode's platform downloads. For simulator play, choose an installed iPhone simulator as the run destination and press **⌘R**.
2. For your phone, sign in through Xcode Settings → Apple Accounts. Select the ParcelPack target → **Signing & Capabilities**, choose your Personal Team, and leave automatic signing enabled. Use a unique bundle identifier if Xcode requests one.
3. Connect and unlock the iPhone, trust the Mac, and select the phone as the run destination. Enable Developer Mode if requested, then press **⌘R**. If the first launch asks you to trust the developer, use Settings → General → VPN & Device Management on the phone and trust your own developer entry.

Apple's [device run guide](https://developer.apple.com/documentation/xcode/running-your-app-on-simulated-or-physical-devices) covers installation. A free Personal Team supports personal device testing with periodic reprovisioning; see [Apple's account overview](https://developer.apple.com/help/account/basics/about-your-developer-account). TestFlight and App Store distribution require separate preparation and have not been performed.

## Development

```sh
swift test
xcodebuild -project ParcelPack.xcodeproj -scheme ParcelPack \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  -configuration Debug -derivedDataPath .build/ios CODE_SIGNING_ALLOWED=NO build
```

The Xcode target compiles the shared Swift files directly. SwiftPM compiles ParcelCore as a separate module; conditional imports support both. After adding source files, regenerate the project with `python3 scripts/generate-project.py`; regeneration preserves existing local signing settings. The checked-in project leaves the development team empty.

To reproduce the balance sample against the actual Swift engine:

```sh
swiftc -O Sources/ParcelCore/Packing.swift Sources/ParcelCore/Shift.swift \
  scripts/measure-shift-balance.swift -o /tmp/parcel-shift-balance
/tmp/parcel-shift-balance 100
```

This samples 100 independent seeds for each of shifts 1–10, comparing reference packing with a strong per-box strategy that manages rush parcels and the shelf. It reports JSON lines; it is not a human difficulty estimate or a globally optimal run solver.

## Verification and contributions

**60 Swift tests pass**, including 500 simulated tycoon deliveries reaching every customer and depot stage with and without hints. Version 1.1 (build 2) builds for Mac, iOS Simulator, and a signed iPhone target. Native play checks cover shipping, upgrades, expansion, and saved progress. The tycoon update is installed and launched on a physical iPhone 15 running iOS 26.7.1. Further phone gesture, audio, and haptic checks remain. See [VALIDATION.md](VALIDATION.md), [DESIGN.md](DESIGN.md), and [AFTER_UPDATE.md](AFTER_UPDATE.md).

Claude contributed the initial SwiftUI presentation and the Shift rules, model, and interface. Codex implemented the original puzzle core and packaging, completed Shift with a faster value solver and fixed orientations, and added the Tycoon economy, persistence, native depot interface, and progression checks. The original focused persistence review used DeepSeek through OpenCode Go. Provider credentials and orchestration logs are excluded from the repository and game.

# Parcel Pack

A native SwiftUI packing puzzle for iPhone and Mac. Choose a scored **Shift** run or the original untimed **Free pack**. Boxes are generated on-device. No timer, ads, purchases, accounts, or network dependency.

## Play

Drag a parcel into the cardboard box, or select it and tap the square for its top-left corner. **Rotate** turns the selected parcel. Tap a packed parcel to remove it; **Undo** removes your last placement. Every fresh box has an exact fill, but Shift gives you more parcels than fit.

### Shift

- Each parcel is worth 1–4 points. Pack any subset and **Seal & ship** when ready. A full box doubles the packed value.
- Keep up to three spare parcels on the **Shelf** for later boxes in the same shift. Unshelve them or pack directly from the shelf. Tray leftovers are returned when you seal.
- Rush deadlines count boxes, not seconds. Returning a rush parcel early or keeping it on the shelf through its due box costs five points. Ordinary returns have no fee.
- Meet the target across five boxes to clear the shift and continue the run. Later shifts ask for more valuable packing and better shelf choices. Missing the target ends the run.
- A shipped box shows its scoring breakdown and the best full-box value available before late fees. The shelf clears between shifts; your best run and current progress save locally.

### Free pack

Fit every parcel into the box. **Hint** places one parcel while keeping a route to completion; it can unpack blocking placements and explains the change. Choose Small (4×4), Medium (5×4), or Large (5×5), then move to another generated box after finishing. The existing box, rotations, settings, and shipped count stay saved separately from Shift.

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
3. Connect and unlock the iPhone, trust the Mac, and select the phone as the run destination. Enable Developer Mode if requested, then press **⌘R**.

Apple's [device run guide](https://developer.apple.com/documentation/xcode/running-your-app-on-simulated-or-physical-devices) covers installation. A free Personal Team supports personal device testing with periodic reprovisioning; see [Apple's account overview](https://developer.apple.com/help/account/basics/about-your-developer-account). TestFlight and App Store distribution require separate preparation and have not been performed.

## Development

```sh
swift test
xcodebuild -project ParcelPack.xcodeproj -scheme ParcelPack \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  -configuration Debug -derivedDataPath .build/ios CODE_SIGNING_ALLOWED=NO build
```

The Xcode target compiles the shared Swift files directly. SwiftPM compiles ParcelCore as a separate module; conditional imports support both. After adding source files, regenerate the project with `python3 scripts/generate-project.py`.

To reproduce the balance sample against the actual Swift engine:

```sh
swiftc -O Sources/ParcelCore/Packing.swift Sources/ParcelCore/Shift.swift \
  scripts/measure-shift-balance.swift -o /tmp/parcel-shift-balance
/tmp/parcel-shift-balance 100
```

This samples 100 independent seeds for each of shifts 1–10, comparing reference packing with a strong per-box strategy that manages rush parcels and the shelf. It reports JSON lines; it is not a human difficulty estimate or a globally optimal run solver.

## Verification and contributions

**33 Swift tests pass**, the native Mac app has been played, and the generic iOS Simulator build succeeds. Simulator gameplay awaits the runtime download; physical iPhone gestures, audio, haptics, and signing remain to be checked. See [VALIDATION.md](VALIDATION.md), [DESIGN.md](DESIGN.md), and [AFTER_UPDATE.md](AFTER_UPDATE.md).

Claude contributed the initial SwiftUI presentation and the Shift rules, model, and interface. Codex implemented the original puzzle core and packaging, then completed Shift with a faster value solver, balance measurements, save validation, native layout fixes, and core tests. The original focused persistence review used DeepSeek through OpenCode Go. Provider credentials and orchestration logs are excluded from the repository and game.

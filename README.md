# Parcel Pack

A native SwiftUI packing puzzle for iPhone. Fit every colorful parcel into its cardboard box. No timer, ads, accounts, lives, purchases, or network dependency. New boxes are generated on-device with guaranteed solutions.


## Play

- Drag a parcel from the tray into the box. It lifts above your finger so you can see the landing spot.
- Or tap a parcel, then tap the square for its top-left corner. This also works with VoiceOver.
- Select a parcel and tap **Rotate** to turn it clockwise.
- Tap a placed parcel to take it out. **Undo** returns the last placed parcel.
- **Hint** packs one parcel that leaves a way to finish. If an earlier placement blocks completion, it unpacks enough parcels to find a route forward and tells you what changed.
- Fill the box and tap **Next box**. Small is 4×4; Medium is 5×4; Large is 5×5.
- The current box, rotations, preferences and shipped count are saved locally. Repacking the same box does not count it twice.

## Install on your iPhone

This checkout includes **ParcelPack.xcodeproj** and a shared **ParcelPack** scheme. Requires iOS 17 or later and Xcode 16 or later with the iOS platform installed. Choose an Xcode release compatible with both your Mac and your iPhone's iOS version using [Apple's compatibility table](https://developer.apple.com/xcode/system-requirements). This Mac runs macOS 15.7.9, which supports Xcode 26.3; newer Xcode releases may require a macOS upgrade.

1. Install [Xcode from Apple](https://developer.apple.com/xcode/), then open `ParcelPack.xcodeproj`.
2. In Xcode → Settings → Apple Accounts, sign in with your own Apple Account.
3. Select the **ParcelPack** target → **Signing & Capabilities**. Choose your Personal Team and leave automatic signing enabled. If the bundle identifier is unavailable, change it to a unique identifier of your own.
4. Connect and unlock your iPhone, trust the Mac, and select the iPhone as the run destination. Enable Developer Mode on the phone if Xcode requests it.
5. Press **Run** (⌘R). If iOS asks you to trust the developer, follow the prompt in Settings. The installed app then plays offline.

A paid developer membership is not required for personal device testing; Apple's free Personal Team provisioning has limits and needs periodic renewal. TestFlight/App Store distribution is a separate step. See [Apple's device run guide](https://developer.apple.com/documentation/xcode/running-your-app-on-simulated-or-physical-devices) and [membership comparison](https://developer.apple.com/support/compare-memberships/).

## Development

There are no external package dependencies. Core generation, placement, hints, persistence and app lifecycle tests run with the Swift command line toolchain:

```sh
swift test
```

The same SwiftUI interface compiles as a native macOS app for local verification:

```sh
zsh scripts/build-mac.sh
open "dist/Parcel Pack.app"
```

The iPhone Xcode target compiles the shared Swift files directly. SwiftPM compiles the core as a separate module. Conditional imports support both arrangements. After adding source files, regenerate the project with:

```sh
python3 scripts/generate-project.py
```

To build for the iPhone simulator once Xcode is installed:

```sh
xcodebuild -project ParcelPack.xcodeproj -scheme ParcelPack \
  -sdk iphonesimulator -configuration Debug CODE_SIGNING_ALLOWED=NO build
```

## Verification status

The development Mac initially had Swift 6.1.2 and the macOS SDK, but no Xcode, iOS SDK or iPhone simulator. The iOS project can be inspected and packaged here; an iOS compilation and physical iPhone installation require Xcode. Detailed final checks are recorded in `VALIDATION.md`.

## Contributions

Claude Code contributed the SwiftUI presentation. DeepSeek through OpenCode Go reviewed the state and persistence code; its initial engine task reached its reasoning limit without producing code. Codex implemented the puzzle engine and tests, state model, persistence, Xcode packaging, integration and verification. Provider credentials stay in their existing stores; orchestration logs are excluded from the app.

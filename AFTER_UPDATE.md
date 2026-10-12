# Continue Parcel Pack on iPhone

The checkout is `/Users/giofiore/parcel-pack`, backed up in the private GitHub repository `Figo5/parcel-pack`. The active development branch is `claude/optimistic-johnson-nmx2si`, with scored Shift runs and the original Free pack. Main still contains the original game.

As of October 12, Xcode 27.0 is installed, its license/setup is complete, all 33 Swift tests pass, and the iOS Simulator binary compiles. The remaining Xcode platform download must finish before simulator play. No physical phone build has been installed.

## Simulator

1. Let Xcode finish downloading its iOS simulator runtime.
2. Open `ParcelPack.xcodeproj`, select the **ParcelPack** scheme, and choose an available iPhone simulator as the run destination.
3. Press **⌘R**. Check drag and tap placement, rotation, undo, shelf carryover, rush deadlines, sealing, the five-box outcome, mode switching, and progress after relaunch.

Use `xcrun simctl list runtimes` to confirm that a runtime is installed. The generic simulator build does not require a booted device:

```sh
xcodebuild -project ParcelPack.xcodeproj -scheme ParcelPack \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  -configuration Debug -derivedDataPath .build/ios CODE_SIGNING_ALLOWED=NO build
```

## Your iPhone

1. In Xcode Settings → Apple Accounts, sign in with your own Apple Account.
2. In the app target's **Signing & Capabilities**, select your Personal Team and automatic signing. Change the bundle identifier if Xcode says it is unavailable.
3. Connect and unlock the iPhone, trust the Mac, select the phone as the run destination, and enable Developer Mode if requested.
4. Press **⌘R**. Check gestures, compact safe areas, sound/haptics, and restored progress on the phone.

Apple's [device run guide](https://developer.apple.com/documentation/xcode/running-your-app-on-simulated-or-physical-devices) covers signing and installation. A free Personal Team supports personal device testing with periodic reprovisioning; see [Apple's account overview](https://developer.apple.com/help/account/basics/about-your-developer-account). Credentials and local signing settings are excluded from Git. Nothing has been distributed through TestFlight or the App Store.

## Mac and development

```sh
swift test
zsh scripts/build-mac.sh
open "dist/Parcel Pack.app"
```

Both modes save locally and separately. In-progress Shift quotas survive balance updates. There are no external package dependencies. Build products and local orchestration logs are ignored.

See [README.md](README.md), [DESIGN.md](DESIGN.md), and [VALIDATION.md](VALIDATION.md) for rules, architecture, and the completed checks.

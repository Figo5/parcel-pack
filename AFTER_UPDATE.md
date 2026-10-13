# Continue Parcel Pack on iPhone

The checkout is `/Users/giofiore/parcel-pack`, backed up in the private GitHub repository `Figo5/parcel-pack`. The active development branch is `claude/optimistic-johnson-nmx2si`, with the new Tycoon mode, scored Shift runs, and the original Free pack. Main still contains the original game.

As of October 13, Xcode 27.0 is installed, its license/setup is complete, all 60 Swift tests pass, and version 1.1 (build 2) compiles for Mac, iOS Simulator, and a signed iPhone target. Tycoon is running on an iPhone 18 Pro simulator with iOS 27.0. The signed phone artifact is `.build/device/Build/Products/Debug-iphoneos/ParcelPack.app`. The earlier version 1.0 is installed and opens on the user’s physical iPhone 15 running iOS 26.7.1; updating that phone to Tycoon awaits reconnection. Apple Account sign-in, Developer Mode, and developer trust are complete.

## Simulator

1. Open Xcode’s Device Hub (Xcode → Open Developer Tool → Device Hub) to see the installed iPhone simulator build.
2. Open `ParcelPack.xcodeproj`, select the **ParcelPack** scheme, and choose an available iPhone simulator as the run destination.
3. Press **⌘R**. In Tycoon, check fixed-shape packing, shipping cash once, equipment purchases, customer unlocks, depot expansion, and progress after relaunch. Shift and Free pack remain available through the top mode picker.

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
4. Press **⌘R**. If iOS asks, trust your own developer entry in Settings → General → VPN & Device Management. Check gestures, compact safe areas, sound/haptics, and restored progress on the phone.

The currently installed version 1.0 Personal Team profile expires October 19, 2026 at 4:31 PM Eastern. Reconnect the phone, select it as the Xcode run destination, and run again to install the tycoon update and refresh provisioning. Xcode’s local project changes retain the selected team; those personal signing settings have not been pushed to GitHub. Project regeneration also preserves them.

Apple's [device run guide](https://developer.apple.com/documentation/xcode/running-your-app-on-simulated-or-physical-devices) covers signing and installation. A free Personal Team supports personal device testing with periodic reprovisioning; see [Apple's account overview](https://developer.apple.com/help/account/basics/about-your-developer-account). Credentials and local signing settings are excluded from Git. Nothing has been distributed through TestFlight or the App Store.

## Mac and development

```sh
swift test
zsh scripts/build-mac.sh
open "dist/Parcel Pack.app"
```

All three modes use fixed shapes with no rotation and save locally and separately. Tycoon saves cash and the paid receipt together; reopening a delivered box cannot pay twice. Older packing boards retain compatible placements and unpack incompatible pieces during migration; earned counts and scores are preserved. In-progress Shift quotas survive balance updates. There are no external package dependencies. Build products and local orchestration logs are ignored.

See [README.md](README.md), [DESIGN.md](DESIGN.md), and [VALIDATION.md](VALIDATION.md) for rules, architecture, and the completed checks.

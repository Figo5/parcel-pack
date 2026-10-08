# Continue Parcel Pack after the Mac update

Parcel Pack is a native SwiftUI game for iPhone (iOS 17+) with unlimited generated boxes, drag or tap placement, rotation, undo, hints, and local saves. The source is backed up in the private GitHub repository `Figo5/parcel-pack`.

The existing local checkout is `/Users/giofiore/parcel-pack`. If you need to restore it elsewhere:

```sh
gh repo clone Figo5/parcel-pack
cd parcel-pack
```

## Finish the iPhone setup

1. Install Xcode compatible with the updated Mac and the iPhone's iOS version. See [Apple's compatibility table](https://developer.apple.com/xcode/system-requirements).
2. Open Xcode once and finish its initial setup, including the iOS platform components.
3. Open `ParcelPack.xcodeproj` and select the **ParcelPack** scheme.
4. In Xcode Settings → Apple Accounts, sign in with your own Apple Account. In the app target's **Signing & Capabilities**, select your Personal Team and automatic signing. Change the bundle identifier if Xcode says it is unavailable.
5. Connect and unlock the iPhone, trust the Mac, enable Developer Mode if requested, select the phone as the run destination, and press **⌘R**.

Apple's [device run guide](https://developer.apple.com/documentation/xcode/running-your-app-on-simulated-or-physical-devices) covers the signing and installation steps. A paid developer account is not required for personal device testing; free provisioning has limits and requires renewal.

## Checks for the next development session

The last local run passed all **15 Swift tests** and produced a working native macOS preview. The interface was tested at 430- and 375-point widths. The previous Mac environment had no Xcode or iOS SDK, so **the iOS build, simulator run, physical iPhone install, phone gestures, audio, and haptics remain unverified**.

After Xcode is installed, check `xcode-select -p` and `xcrun --find simctl`. If command-line tools still select the standalone toolchain, select the installed Xcode through its Settings → Locations → Command Line Tools.

Then run:

```sh
swift test
xcodebuild -project ParcelPack.xcodeproj -scheme ParcelPack \
  -sdk iphonesimulator -configuration Debug CODE_SIGNING_ALLOWED=NO build
```

Test drag placement, invalid/outside drops, tap placement, rotation, undo, hint recovery, finishing a box, next box, changing size, and restoring progress after relaunch. Follow the user through Apple Account authentication if needed; credentials are not stored in this repository.

The project has no external package dependencies. Generated builds, provider logs, local user settings and signing credentials are excluded from Git. Nothing has been distributed through TestFlight or the App Store.

For architecture, contributions and prior checks, see `README.md`, `DESIGN.md`, and `VALIDATION.md`.

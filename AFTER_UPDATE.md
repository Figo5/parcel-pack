# Continue Parcel Pack

Checkout: `/Users/giofiore/parcel-pack`. Private GitHub repository: `Figo5/parcel-pack`. Development branch: `claude/optimistic-johnson-nmx2si`. Main remains unchanged.

As of October 13, version **1.3, build 4** is installed and launched on the user's iPhone 15 running iOS 26.7.1. A filtered device app listing confirms both version numbers. Xcode 27.0 setup, Apple Account sign-in, Developer Mode, Keychain authorization, and developer trust are complete. The phone can be unplugged for normal play.

The game has **Tycoon** and endless **Free play**. Version 1.3 makes every hired worker team ship earnings automatically, including up to eight hours offline; managers now boost packing speed and pay by 25%. Older waiting orders are credited once on launch. The depot has a richer shipping-floor illustration and live automatic-income summary. Tycoon retains the chosen customer and six 30-level equipment lines. Shift remains removed; historical Shift/Free pack save keys are untouched.

## Development

```sh
swift test
zsh scripts/build-mac.sh
open "dist/Parcel Pack.app"
```

All 99 tests pass. Native Mac, simulator, and signed device builds succeed. Open Xcode's Device Hub to view the iPhone 18 Pro simulator.

```sh
xcodebuild -project ParcelPack.xcodeproj -scheme ParcelPack \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  -configuration Debug -derivedDataPath .build/ios CODE_SIGNING_ALLOWED=NO build
```

The signed artifact is `.build/device/Build/Products/Debug-iphoneos/ParcelPack.app`. For future phone updates, connect and unlock the phone, choose it as the Xcode run destination, and press **⌘R**. The local target retains the Personal Team; project regeneration preserves that choice. Personal signing settings are not pushed to GitHub.

The installed profile expires October 19, 2026 at 4:31 PM Eastern. Run from Xcode again when provisioning needs renewal. No TestFlight or App Store distribution has been performed.

See [README.md](README.md), [DESIGN.md](DESIGN.md), and [VALIDATION.md](VALIDATION.md) for rules, persistence contracts, and verification evidence. Keep staff timestamps and payouts in one saved snapshot, preserve manual receipt sequences independently of automatic deliveries, and retain selected customers when generating the next order.

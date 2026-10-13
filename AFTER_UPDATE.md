# Continue Parcel Pack

Checkout: `/Users/giofiore/parcel-pack`. Private GitHub repository: `Figo5/parcel-pack`. Development branch: `claude/optimistic-johnson-nmx2si`. Main remains unchanged.

October 13 update: **2.0, build 5** is installed on the user's iPhone 15 (iOS 26.7.1). Device Control confirms the installation and both version numbers. Remote launch was blocked by the phone locking again; the user can unlock it and open Parcel Pack normally. Native Mac and simulator builds are also installed and running. The phone can be unplugged for normal play.

Parcel Pack is now entirely Tycoon. Five tabs: Pack, Orders, Crew, Depot, World. Contracts, permanent customer trust, milestone equipment, manual dispatch boosts/blueprints, manager specialties, satellite neighborhoods/customers, voluntary franchising and Head Office are connected. Every hired team banks earnings automatically. Offline work is eight hours, expandable to eighteen via Logistics. Existing Tycoon progress migrates; historic Free Play/Shift saves remain untouched.

Franchising requires Shipping hub and one landmark contract. The review explicitly lists resets and retained values. It clears the current run but preserves trust, blueprints, stars, Head Office, lifetime records, and unlocked neighborhood access. Account, fresh Corner Market session, seed and production watermark reset atomically. Starter packages apply on the next franchise; buying Established Business immediately after a reset is valid.

## Development

```sh
swift test
zsh scripts/build-mac.sh
open "dist/Parcel Pack.app"
```

All 121 tests pass (81 core, 40 app-model). Native Mac, simulator, and signed device builds succeed. All 22 shared sources are in the Xcode project. Open Xcode's Device Hub to view the iPhone 18 Pro simulator.

```sh
xcodebuild -project ParcelPack.xcodeproj -scheme ParcelPack \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  -configuration Debug -derivedDataPath .build/ios CODE_SIGNING_ALLOWED=NO build
```

The signed artifact is `.build/device/Build/Products/Debug-iphoneos/ParcelPack.app`. For future phone updates, connect/unlock the phone, select it in Xcode, and press **⌘R**. Xcode setup, Apple Account sign-in, Developer Mode, Keychain authorization, and developer trust are already complete. The local target retains the Personal Team; regeneration preserves it. Never stage the working project file's personal signing fields. Generate an unsigned canonical project separately and stage its blob while retaining local signing.

Save schema 3 reads versions 1...3. Progression lives in the same snapshot as business, current box, receipt and staff time. Settle elapsed production before rate-changing actions, process worker/branch events chronologically, reserve outstanding contract reward headroom, and keep manual receipt sequences independent of automation. Do not clear existing saves or auto-prestige an old business.

The installed developer profile expires October 19, 2026 at 4:31 PM Eastern. Run from Xcode again when renewal is needed. No TestFlight or App Store distribution has been performed. See README.md, DESIGN.md and VALIDATION.md for rules and evidence.

# Parcel Pack

A native SwiftUI packing game for iPhone and Mac. Build a shipping business in **Tycoon**, or chase a high score in endless **Free play**. Parcels stay in the orientation shown: no rotation. No ads, real-money purchases, accounts, or network dependency.

## Tycoon

Fill a customer box and **Ship** it for cash. Free hints help finish tricky boxes; packing without hints adds a bonus worth 20% of the customer's base pay. Choose a store in **Orders** and keep packing for that store until you select another. Your current customer and partially packed box survive relaunch.

Eight customers unlock through deliveries and depot growth. Grow from **Spare room** through **Shopfront**, **Local depot**, and **Warehouse** to a **Shipping hub**. Both your manual shipments and automatic staff deliveries count toward these milestones.

### Equipment and crew

Six equipment lines each have 30 levels:

| Upgrade | Benefit per level |
| --- | --- |
| Workbench | +$8 per delivery |
| Storage shelves | +$4 per delivery |
| Label printer | +$6 per delivery |
| Delivery van | +10% on base and equipment pay |
| Conveyor belt | Faster worker packing |
| Dispatch desk | +5% worker payout |

In **Crew**, hire teams for the first six stores. Each team supports up to 20 workers. Every hired team packs continuously and sends earnings straight to your cash balance, including up to eight hours of work while the app is closed. No collection taps or holding-area limit. Managers add **25% packing speed and 25% earnings**. Worker shipments start at half the base/equipment payout and benefit from the van and dispatch desk; they do not receive the manual clean-pack bonus.

The depot scene reflects your equipment, workers, managers, and building, with marked work areas, richer storage and loading details, and a live staff income summary. Cash, equipment, staff, active order, paid receipt, and production timestamp save together. Reopening a paid box or restoring elapsed production twice cannot pay again. Existing businesses migrate without resetting cash, equipment, building, or the chosen customer; orders waiting in older saves are credited automatically once.

## Endless Free play

Place fixed pieces on an **8×8** board. You receive three pieces at a time; the tray refills after all three are used. Filling a row or column clears it. Intersecting full rows and columns clear together.

Earn **10 points per placed square** and **100 points per cleared line**. The score keeps building in the same run until none of the remaining pieces fits. Your best score, board, tray, and current score save locally. **Hint** highlights a legal placement without placing it or awarding points. **New game** asks before abandoning a live run. Drag a piece into position, or select it and tap its top-left square.

Shift has been removed from the playable modes. The previous Shift and exact-fill Free pack save keys remain untouched; Free play now has its own saved run and record.

## Play on this Mac

```sh
zsh scripts/build-mac.sh
open "dist/Parcel Pack.app"
```

The script packages the current SwiftPM release binary. There are no external package dependencies.

## Install on your iPhone

Open **ParcelPack.xcodeproj** and select the shared **ParcelPack** scheme. The target supports iOS 17 or later.

1. Finish Xcode's platform downloads. For simulator play, choose an installed iPhone simulator and press **⌘R**.
2. For your phone, sign in through Xcode Settings → Apple Accounts. Select the target → **Signing & Capabilities**, choose your Personal Team, and leave automatic signing enabled.
3. Connect and unlock the iPhone, trust the Mac, and select it as the run destination. Enable Developer Mode if requested, then press **⌘R**. If first launch requests developer trust, use Settings → General → VPN & Device Management on the phone.

Once installed, the phone can be disconnected for normal play. Apple's [device run guide](https://developer.apple.com/documentation/xcode/running-your-app-on-simulated-or-physical-devices) covers installation. TestFlight and App Store distribution have not been performed.

## Development and verification

```sh
swift test
xcodebuild -project ParcelPack.xcodeproj -scheme ParcelPack \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  -configuration Debug -derivedDataPath .build/ios CODE_SIGNING_ALLOWED=NO build
```

The Xcode target compiles shared sources directly; SwiftPM compiles ParcelCore separately. After adding source files, regenerate with `python3 scripts/generate-project.py`. Regeneration preserves local signing settings; the checked-in project leaves the development team empty.

See [VALIDATION.md](VALIDATION.md) for current test and device evidence, [DESIGN.md](DESIGN.md) for rules and presentation, and [AFTER_UPDATE.md](AFTER_UPDATE.md) for continuing native development. Legacy core/model tests remain as regression coverage for retained save data and shared packing helpers.

Claude contributed the initial native presentation and Shift rules. Codex implemented the puzzle core, packaging, fixed blocks, Tycoon, staff automation, and endless Free play through parallel implementation and independent review. Credentials, build products, and orchestration logs stay outside Git.

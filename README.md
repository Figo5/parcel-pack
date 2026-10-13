# Parcel Pack

A native SwiftUI shipping tycoon for iPhone and Mac. Pack fixed-shape parcels, build customer relationships, hire crews, and grow from a spare room into a franchise network. No rotation, ads, real-money purchases, accounts, or network dependency.

## Run your depot

**Pack** fills a customer's box. Ship a complete box for cash; free hints help with difficult arrangements. Packing without hints earns a clean bonus worth 20% of the customer's base pay. Your chosen customer and partially packed box stay saved. Every manual shipment also banks two dispatch boosts: each boosts a future worker delivery's pay by 20%, with room for 120 boosts.

**Orders** holds contracts and the customer catalog. Choose one contract at a time. Supply runs count matching manual and crew shipments; premium jobs and landmark contracts count your own packing. Rewards go into cash automatically when the job finishes. Contracts have no deadlines. Premium completions add 12 dispatch boosts and one permanent packing blueprint, worth +2% manual pay each up to ten blueprints. Shipping builds customer trust: three XP per manual shipment and one per crew shipment. Trust ranks at 10/30/75/150/300 XP add 3% pay per rank and survive franchising.

**Crew** hires workers and managers. The six original smaller stores and new neighborhood customers support teams of up to 20 workers. Every team ships continuously and banks earnings automatically, including offline work. Managers give +25% speed and pay, and unlock a freely assignable specialty: Express for speed, Careful for pay, or Mentor for faster customer relationships. Manual packing's boost stock is shared across your teams.

**Depot** buys equipment and expands your main building through Spare room, Shopfront, Local depot, Warehouse, and Shipping hub. Manual and automatic deliveries count toward growth. Six equipment lines have 30 levels; milestone levels 5/10/20/30 change their identity and add meaningful pay or speed bonuses. The shipping-floor illustration reflects owned equipment, milestones, crew, and neighborhood. The workforce summary estimates actual automatic income.

**World** opens neighborhood branches and manages your franchise. Harbor, Arts Quarter, and Uptown become available after one, two, and three franchises. Once your main building reaches Shipping hub, open their satellite depots and grow each through ten levels. Branches ship on a 60-second cycle alongside your existing crews; visiting a district keeps your current box and original business intact. New district customers include Harbor Outfitters, Gallery Store, and Uptown Boutique.

## Franchise your business

Reach Shipping hub and finish a landmark contract to qualify. The review screen shows the star reward, progress toward the next earnings star, and exactly what stays and resets. Franchising is voluntary and requires confirmation.

The current run's cash, equipment, crew, building, branches, contracts, dispatch boosts, and active box reset. Customer trust, blueprints, lifetime records, stars, Head Office upgrades, and access to unlocked neighborhoods stay. A fresh order seed separates the new business from old paid orders.

Franchise Stars depend on total run earnings and landmark completions, so spending cash does not lower the reward. Head Office offers five permanent upgrade lines:

| Upgrade | Benefit per level |
| --- | --- |
| Training | +10% crew speed and +5% branch pay |
| Buying power | Equipment costs 5% less |
| Premium service | +10% manual shipment pay |
| Established business | Next franchise starts with $250 per level and a Corner Market worker |
| Logistics | Two additional offline earning hours |

Each line has five levels, costing 1/2/3/4/5 stars. Offline catchup starts at eight hours and reaches eighteen with Logistics. Starter packages apply to the next franchise, rather than granting cash when purchased.

## Saves

Cash, progression, crew, current box, paid receipt, and production timestamp save together. Reopening a paid box or restoring elapsed production twice cannot pay again. Elapsed production settles at prior rates before purchases or specialty changes. Existing Tycoon businesses migrate without resetting progress; orders waiting in older saves bank their saved payout once. Lifetime records retain existing totals; new per-customer trust starts from subsequent shipments.

Free Play and Shift have been removed from app navigation and lifecycle. Their historical save keys remain untouched; shared helpers and legacy tests remain as regression coverage.

## Play on this Mac

```sh
zsh scripts/build-mac.sh
open "dist/Parcel Pack.app"
```

The script packages the current SwiftPM release binary. There are no external package dependencies.

## Install on your iPhone

Open **ParcelPack.xcodeproj**, select the shared **ParcelPack** scheme, and choose your iPhone or an installed simulator. The target supports iOS 17 or later.

For a physical phone, finish Xcode's platform downloads and Apple Account sign-in. Choose your Personal Team under Signing & Capabilities, connect and unlock the phone, enable Developer Mode, and press **⌘R**. If first launch requests developer trust, use Settings → General → VPN & Device Management. The phone can be disconnected for normal play after installation.

## Development

```sh
swift test
xcodebuild -project ParcelPack.xcodeproj -scheme ParcelPack \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  -configuration Debug -derivedDataPath .build/ios CODE_SIGNING_ALLOWED=NO build
```

The Xcode target compiles shared sources directly; SwiftPM compiles ParcelCore separately. After adding source files, regenerate with `python3 scripts/generate-project.py`. Regeneration preserves local signing settings; the checked-in project leaves the development team empty.

See [VALIDATION.md](VALIDATION.md), [DESIGN.md](DESIGN.md), and [AFTER_UPDATE.md](AFTER_UPDATE.md) for verification, behavior contracts, and continuation details. Build products, credentials, personal signing settings, and orchestration logs stay outside Git.

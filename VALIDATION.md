# Parcel Pack validation

Date: October 13, 2026 (America/New_York). Current update: **2.0, build 5**.

## Builds and automated checks

- The full Swift suite passes: **121 tests**, comprising 81 core tests in ten suites and 40 app-model tests in seven suites. Swift 6.4, Xcode 27.0 (27A266a).
- Native Mac release packaging, generic iOS Simulator, and signed generic iOS builds compile all 22 shared source files. The simulator target builds without signing. Deployment target remains iOS 17.0; no external dependencies were added.
- Strict/deep codesign verification passes for the signed artifact. Device Control installed version 2.0/build 5 on the physical iPhone 15 and a filtered app listing confirms both numbers. Launch was blocked by the phone locking again; physical runtime checks remain.
- Personal signing remains local; the canonical Git project leaves the team empty and regeneration retains the local choice. Branch backup is `claude/optimistic-johnson-nmx2si`; Main is unchanged.

## New progression coverage

- Thirteen progression tests cover deterministic contract variants and validated acceptance, once-only automatic supply rewards, premium manual-only progress, blueprint and finite dispatch rewards, bounded relationships and prior-rank pay, chronological production equivalence, exact 120-second worker and 60-second branch completion boundaries, real milestone/specialty effects, all district branches/customers, voluntary franchise reset, Head Office/star/starter-grant rules, money reservations/limits, and migration.
- Initial one-customer offers provide distinct shorter Special delivery and longer Gift collection jobs. Accepted longer jobs survive reload and complete under their canonical reward rules. Expanding to Shipping hub while a premium third-slot contract is active preserves the accepted job instead of replacing it with a landmark.
- A three-team two-hour batch agrees with 7,200 one-second foreground ticks for revenue, actual shipments, trust thresholds, boost exhaustion, contract progress, and completion payment. Branches run alongside the main business and never fabricate customer XP.
- Automated and manual shipments reserve active contract rewards and historic waiting cash within money/counter bounds. Contract payment and progression happen in the same account mutation; a completed job cannot be accepted or paid again.
- Franchising requires Shipping hub and a completed landmark. Purchases do not reduce the star reward. Reset uses a fresh seed, clears run state, preserves trust/blueprints/stars/Head Office/lifetime records, and explicitly supports starter cash and workers. Established Business can be purchased immediately after reset, and an earned starter package supports equipment purchases before the first manual shipment.
- Eight new app-model tests verify acceptance retains a partial box; premium completion/relaunch pays once and retains the receipt; franchise preview cancellation preserves the box; confirmation atomically saves the new account, order and clock; immediate permanent purchases persist; specialties settle prior-rate work; a branch-only business earns without workers while visits retain the box; locked reset is rejected; and historical Free Play saves remain untouched.

## Saves and retained regressions

- Save schema 3 accepts versions 1...3 under the existing 128 KB bound. Old cash, equipment, crew, current customer, partial box, receipt and production watermark survive missing new fields. Lifetime totals seed from existing aggregate counters; historical per-store XP is not invented.
- Individual malformed optional progression values are repaired. A full Harbor business with workers, specialties and a partially packed Harbor order retains its healthy state when a boost is negative/wrong-typed or active contract metadata has an invalid round/reward. Entirely unreadable modern progression is conservatively rejected rather than inventing neighborhood ownership.
- Staff timestamps and income save together. Clock rollback/relaunch does not duplicate work. Historical waiting orders pay their saved rate once, even at zero elapsed time; they do not alter manual order sequence or historical receipt.
- Existing generated packing, sticky-customer, upgrade purchasing, expansion reachability, receipt replay, hint, orientation, bounds, save-repair, and legacy Shift/Free pack/Endless tests remain. All parcels stay fixed in orientation. No Free Play or Shift model is created or saved by the playable app lifecycle.

## Native play and layout checks

- Updated Mac app restores the existing Shopfront, purchased equipment, managed Corner Market team, unmanaged Chapter & Co. team, $9,441 cash, and paid Circuit Supply order 20. Free Play and the mode picker are absent; all five Tycoon tabs are present.
- Accepted a premium Chapter & Co. job through Orders without replacing the paid Circuit box. Its separate Pack action selected Chapter & Co. Played and shipped three hinted boxes; progress advanced 1/3 and 2/3, then the $1,500 contract bonus banked automatically. The saved account shows one permanent blueprint and stored dispatch charges, with crew consumption continuing independently. Subsequent orders retained Chapter & Co.
- Bought Workbench levels 2/3/4/5 for $480/$1,080/$1,920/$3,000. Cash deducted the actual $6,480 total; level 5 displays Twin packing bench, +10% milestone manual pay, and the next transformation at level 10. Equipment and branch income displays use actual saved state/rates.
- Mac Orders/World/Depot render readable contract choices, trust, district requirements, current income, equipment progression and Head Office/franchise requirements at 375-point width. A compact Pack refinement preserves at least 44-point board cells while reducing space above the tray in short windows.
- The final compact Mac build restores the Chapter & Co. receipt, blueprint, trust rank 1 and milestone equipment without repaying the job. Its next supply contract accepts safely; Pack for that customer opens the next saved-sequence box with a visible parcel tray and compact contract/boost strip.
- iPhone 18 Pro simulator portrait shows active packing, parcel tray/actions, the contract board, safe areas and five bottom tabs. It retains earlier simulator cash and box. Endgame branch/prestige behavior is verified by model/core tests and independent source review; a complete endgame native playthrough has not been performed.
- Further physical finger, enlarged-text, VoiceOver, haptic and audio checks remain. No TestFlight, IPA export or App Store release has been performed.

Build products and orchestration logs remain ignored. See AFTER_UPDATE.md for the verified physical-device version and installation status.

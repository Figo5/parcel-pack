# Parcel Pack validation

Date: October 8, 2026 (America/New_York).

## Passed

- `swift test`: **15 tests pass** under Swift 6.1.2 on Apple Silicon macOS 15.7.9. Both the core and the SwiftUI executable compile in Swift 6 mode.
- Generation: 180 seeds across Small, Medium and Large have valid connected parcels, exact coverage and a working reference tiling. Determinism and shape/tray variety are checked.
- Hints: 90 generated boxes, both empty and partially packed, finish through valid hints. A legal placement that blocks completion is detected; the app recovers by unpacking it and explains the change.
- Rotation: clockwise quarter turns, four-turn identity, negative rotations, and extreme integer values.
- Placement: invalid bounds, duplicate parcels, unknown IDs, overlaps, atomic failure, undo and reset. Alternate complete tilings are accepted.
- Persistence: current progress and settings round-trip; first box saves immediately; shipped count credits once per box; rejected/corrupt box data cannot erase the separately saved lifetime count.
- Native macOS UI: actual tap-select/place, undo, rotate, drag-and-drop of a rotated parcel, outside-drop cancellation, size-change confirmation and changing to a Large box.
- Rendered at 430 points wide and resized to 375 points wide. At the compact size the board, all five tray parcels and the Undo/Rotate/Hint buttons remain visible together.
- Xcode project property list, shared scheme and asset-catalog JSON validated. 1024×1024 opaque RGB app icon included. The project references all five Swift source files.
- iOS source syntax was parsed targeting arm64 iOS 17. This is a syntax check only, not an iOS compilation.

## Still requires Xcode / an iPhone

This Mac has Command Line Tools and the macOS SDK, but **no Xcode or iOS SDK**. No iOS binary or signed IPA has been produced. Simulator testing, a physical iPhone installation, iPhone touch behavior, audio and haptics remain unverified. The macOS render is a native preview using the shared SwiftUI views, not an iPhone simulator.

The prepared `ParcelPack.xcodeproj` uses automatic signing with no developer team selected. The user must select their own Apple Account/Personal Team in Xcode and run on their iPhone. Nothing has been published to the App Store or TestFlight.

## Orchestration

Claude Code authored the initial SwiftUI views. Codex adjusted the compact tray, implemented the engine, persistence and state model, generated the Xcode project, and performed testing and integration.

DeepSeek v4.1 Flash's initial engine task and first focused review both stopped at their reasoning limit without returning code or findings. A focused review with **DeepSeek v4 Flash through OpenCode Go** completed, found no blocking issues and identified two save edges; both were fixed and regression-tested. Credentials and provider logs are not bundled with the game or source download.

import SwiftUI
#if SWIFT_PACKAGE
import ParcelCore
#endif

struct RootView: View {
    @Bindable var tycoon: TycoonModel
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TycoonView(model: tycoon)
            .background(Palette.background.ignoresSafeArea())
            .tint(Palette.accent)
            .preferredColorScheme(.light)
            .task(id: scenePhase) {
                guard scenePhase == .active else { return }
                while !Task.isCancelled {
                    tycoon.refreshStaff()
                    do { try await Task.sleep(for: .seconds(1)) } catch { break }
                }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { tycoon.refreshStaff() }
            }
    }
}

import SwiftUI
#if SWIFT_PACKAGE
import ParcelCore
#endif

@main
struct ParcelPackApp: App {
    @State private var model = GameModel()
    @State private var shiftModel = ShiftModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView(game: model, shift: shiftModel)
                #if os(macOS)
                .frame(minWidth: 375, idealWidth: 430, minHeight: 700, idealHeight: 850)
                #endif
        }
        #if os(macOS)
        .defaultSize(width: 430, height: 850)
        .windowResizability(.contentMinSize)
        .windowStyle(.hiddenTitleBar)
        #endif
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                model.save()
                shiftModel.save()
            }
        }
    }
}

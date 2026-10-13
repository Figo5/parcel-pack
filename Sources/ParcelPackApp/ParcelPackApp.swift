import SwiftUI
#if SWIFT_PACKAGE
import ParcelCore
#endif

@main
struct ParcelPackApp: App {
    @State private var endlessModel = EndlessModel()
    @State private var tycoonModel = TycoonModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView(endless: endlessModel, tycoon: tycoonModel)
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
                endlessModel.save()
                tycoonModel.save()
            }
        }
    }
}

import SwiftUI
#if SWIFT_PACKAGE
import ParcelCore
#endif

enum PlayMode: String, CaseIterable {
    case tycoon
    case free

    var title: String {
        switch self {
        case .tycoon: return "Tycoon"
        case .free: return "Free play"
        }
    }
}

struct RootView: View {
    @Bindable var endless: EndlessModel
    @Bindable var tycoon: TycoonModel
    @AppStorage("parcel-pack.mode") private var modeRaw: String = PlayMode.tycoon.rawValue
    @AppStorage("parcel-pack.tycoon-introduced.v1") private var introducedTycoon = false
    @Environment(\.scenePhase) private var scenePhase

    private var selectedMode: PlayMode { PlayMode(rawValue: modeRaw) ?? .tycoon }

    private var modeBinding: Binding<PlayMode> {
        Binding(
            get: { PlayMode(rawValue: modeRaw) ?? .tycoon },
            set: { modeRaw = $0.rawValue }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Mode", selection: modeBinding) {
                ForEach(PlayMode.allCases, id: \.self) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .frame(maxWidth: 520)
            modeContent
        }
        .background(Palette.background.ignoresSafeArea())
        .tint(Palette.accent)
        .preferredColorScheme(.light)
        .onAppear {
            if !introducedTycoon {
                modeRaw = PlayMode.tycoon.rawValue
                introducedTycoon = true
            }
            if PlayMode(rawValue: modeRaw) == nil { modeRaw = PlayMode.tycoon.rawValue }
        }
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

    @ViewBuilder private var modeContent: some View {
        switch selectedMode {
        case .tycoon:
            TycoonView(model: tycoon)
        case .free:
            EndlessView(model: endless)
        }
    }
}

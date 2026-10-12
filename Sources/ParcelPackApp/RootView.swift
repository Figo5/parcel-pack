import SwiftUI
#if SWIFT_PACKAGE
import ParcelCore
#endif

enum PlayMode: String, CaseIterable {
    case shift
    case free

    var title: String {
        switch self {
        case .shift: return "Shift"
        case .free: return "Free pack"
        }
    }
}

struct RootView: View {
    @Bindable var game: GameModel
    @Bindable var shift: ShiftModel
    @AppStorage("parcel-pack.mode") private var modeRaw: String = PlayMode.shift.rawValue

    private var selectedMode: PlayMode { PlayMode(rawValue: modeRaw) ?? .shift }

    private var modeBinding: Binding<PlayMode> {
        Binding(
            get: { PlayMode(rawValue: modeRaw) ?? .shift },
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
    }

    @ViewBuilder private var modeContent: some View {
        switch selectedMode {
        case .shift:
            ShiftView(model: shift)
        case .free:
            GameView(model: game)
        }
    }
}

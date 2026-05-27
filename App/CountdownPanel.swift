import AppKit
import SwiftUI

// MARK: - ViewModel

@MainActor
private final class CountdownVM: ObservableObject {
    @Published var remaining: Int = 0
}

// MARK: - Panel controller

/// Shows a floating countdown overlay. Await `show(seconds:)` — returns when done.
@MainActor
final class CountdownPanel {

    static let shared = CountdownPanel()

    private var panel: NSPanel?
    private let vm = CountdownVM()

    /// Blocks until countdown reaches 0. No-op if seconds ≤ 0.
    func show(seconds: Int) async {
        guard seconds > 0 else { return }

        if panel == nil { buildPanel() }
        panel?.center()
        panel?.orderFront(nil)

        for i in stride(from: seconds, through: 1, by: -1) {
            vm.remaining = i
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }

        panel?.orderOut(nil)
    }

    private func buildPanel() {
        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 120, height: 120),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        p.level           = .popUpMenu
        p.backgroundColor = .clear
        p.isOpaque        = false
        p.hasShadow       = false
        p.contentView     = NSHostingView(rootView: CountdownView(vm: vm))
        panel = p
    }
}

// MARK: - SwiftUI view

private struct CountdownView: View {
    @ObservedObject var vm: CountdownVM

    var body: some View {
        ZStack {
            Circle()
                .fill(.black.opacity(0.75))
                .shadow(radius: 12)
            Text("\(vm.remaining)")
                .font(.system(size: 54, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .contentTransition(.numericText(countsDown: true))
                .animation(.spring(duration: 0.35), value: vm.remaining)
        }
        .frame(width: 100, height: 100)
        .padding(10)
    }
}

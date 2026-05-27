import SwiftUI

// MARK: - OverlayToolbarView

/// ShareX-style toolbar that lives at the top of the frozen-screen overlay.
/// Slides in from above when the overlay appears.
struct OverlayToolbarView: View {
    @ObservedObject var vm: OverlayViewModel

    // Tool groups matching ShareX layout
    private let regionGroup: [(AnnotationTool, String, String)] = [
        (.region, "camera.viewfinder",      "Select Region"),
        (.select, "cursorarrow",             "Select / Move"),
    ]
    private let shapeGroup: [(AnnotationTool, String, String)] = [
        (.rect,      "rectangle",            "Rectangle"),
        (.ellipse,   "oval",                 "Ellipse"),
        (.line,      "line.diagonal",        "Line"),
        (.arrow,     "arrow.up.right",       "Arrow"),
        (.pen,       "pencil",               "Freehand"),
    ]
    private let textGroup: [(AnnotationTool, String, String)] = [
        (.text, "textformat",                "Text"),
        (.step, "number.circle",             "Step Number"),
    ]
    private let effectGroup: [(AnnotationTool, String, String)] = [
        (.highlight, "highlighter",          "Highlight"),
        (.blur,      "aqi.medium",           "Blur"),
        (.pixelate,  "squareshape.squareshape.dashed", "Pixelate"),
        (.blackout,  "rectangle.fill",       "Blackout"),
    ]

    var body: some View {
        HStack(spacing: 0) {
            toolGroup(regionGroup)
            divider()
            toolGroup(shapeGroup)
            divider()
            toolGroup(textGroup)
            divider()
            toolGroup(effectGroup)
            divider()

            // Tool options
            toolOptions()

            Spacer()

            // Undo
            Button {
                vm.undo()
            } label: {
                Image(systemName: "arrow.uturn.backward")
                    .toolbarIconStyle()
            }
            .buttonStyle(.plain)
            .disabled(!vm.canUndo)
            .keyboardShortcut("z", modifiers: .command)
            .padding(.trailing, 4)

            divider()

            // Cancel
            Button("Cancel") { vm.onCancel?() }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .keyboardShortcut(.escape, modifiers: [])

            // Done
            Button(action: { vm.onDone?() }) {
                Text("Done")
                    .bold()
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(vm.hasSelection ? Color.accentColor : Color.gray.opacity(0.4))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
            }
            .buttonStyle(.plain)
            .disabled(!vm.hasSelection)
            .padding(.trailing, 8)
            .keyboardShortcut(.return, modifiers: .command)
        }
        .frame(height: 44)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    // MARK: Helpers

    @ViewBuilder
    private func toolGroup(_ tools: [(AnnotationTool, String, String)]) -> some View {
        HStack(spacing: 2) {
            ForEach(tools, id: \.0.rawValue) { tool, icon, tip in
                Button {
                    vm.activeTool = tool
                } label: {
                    Image(systemName: icon)
                        .toolbarIconStyle()
                        .background(
                            vm.activeTool == tool
                                ? Color.accentColor.opacity(0.2)
                                : Color.clear
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
                .help(tip)
            }
        }
        .padding(.horizontal, 4)
    }

    @ViewBuilder
    private func toolOptions() -> some View {
        HStack(spacing: 6) {
            // Color well — hidden for region/select/blur/pixelate/blackout
            if ![.region, .select, .blur, .pixelate, .blackout].contains(vm.activeTool) {
                ColorWellRepresentable(color: $vm.strokeColor)
                    .frame(width: 28, height: 22)
            }

            // Line width — shapes and pen only
            if [.rect, .ellipse, .line, .arrow, .pen].contains(vm.activeTool) {
                Stepper(value: $vm.lineWidth, in: 1...12, step: 1) {
                    Text("\(Int(vm.lineWidth))px")
                        .font(.caption).monospacedDigit().frame(width: 32)
                }
                .frame(width: 88)
            }

            // Font size — text only
            if vm.activeTool == .text {
                Stepper(value: $vm.fontSize, in: 10...72, step: 2) {
                    Text("\(Int(vm.fontSize))pt")
                        .font(.caption).monospacedDigit().frame(width: 32)
                }
                .frame(width: 88)
            }

            // Blur radius
            if vm.activeTool == .blur {
                HStack(spacing: 4) {
                    Image(systemName: "aqi.low")
                    Slider(value: $vm.blurRadius, in: 5...50)
                        .frame(width: 80)
                    Image(systemName: "aqi.high")
                }
                .font(.caption)
            }

            // Pixelate size
            if vm.activeTool == .pixelate {
                HStack(spacing: 4) {
                    Text("Size:")
                        .font(.caption)
                    Stepper(value: $vm.pixelateSize, in: 4...40, step: 2) {
                        Text("\(Int(vm.pixelateSize))")
                            .font(.caption).monospacedDigit().frame(width: 24)
                    }
                    .frame(width: 72)
                }
            }
        }
        .padding(.horizontal, 6)
    }

    private func divider() -> some View {
        Divider().frame(height: 22).padding(.horizontal, 2)
    }
}

// MARK: - Icon style

private extension Image {
    func toolbarIconStyle() -> some View {
        self.font(.system(size: 14))
            .frame(width: 30, height: 30)
    }
}

// MARK: - ColorWell NSViewRepresentable

struct ColorWellRepresentable: NSViewRepresentable {
    @Binding var color: NSColor

    func makeNSView(context: Context) -> NSColorWell {
        let w = NSColorWell()
        w.color = color
        w.target = context.coordinator
        w.action = #selector(Coordinator.changed(_:))
        return w
    }

    func updateNSView(_ v: NSColorWell, context: Context) { v.color = color }
    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject {
        var parent: ColorWellRepresentable
        init(_ p: ColorWellRepresentable) { parent = p }
        @objc func changed(_ s: NSColorWell) { parent.color = s.color }
    }
}

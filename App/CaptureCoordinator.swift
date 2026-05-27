import AppKit
import CoreGraphics
import Defaults
import CentreeCapture
import CentreeCore
import CentreeOverlay
import CentreePipeline
import Foundation

/// Top-level coordinator — owns the full ShareX-style capture flow:
///
/// ```
/// Hotkey → Freeze screens → Overlay with inline annotation toolbar
///        → Render annotated image → Pipeline (clipboard + save)
///        → Thumbnail preview
/// ```
@MainActor
final class CaptureCoordinator: ObservableObject {

    // MARK: - Dependencies

    private let capturer   = Capturer()
    private let provider   = DisplayProvider()
    private let pipeline   = PipelineRunner()
    private let overlay    = OverlayWindowController()
    private let thumbnail  = ThumbnailController()

    // MARK: - Public actions

    func captureWithOverlay() { Task { await runOverlayCapture() } }
    func captureFullScreen()  { Task { await runFullScreen()    } }

    // MARK: - Overlay flow

    private func runOverlayCapture() async {
        do {
            let (displays, scWindows) = try await provider.fetchContent()
            guard !displays.isEmpty else { return }

            var backgrounds: [(frame: CGRect, image: CGImage)] = []
            for display in displays {
                let shot = try await capturer.capture(mode: .fullScreen(displayID: display.displayID))
                backgrounds.append((frame: display.frame, image: shot.image))
            }

            let result = await overlay.show(backgrounds: backgrounds, scWindows: scWindows)
            guard case .captured(let image, let sourceRect, let scale) = result else { return }

            let screenshot = Screenshot(image: image, sourceRect: sourceRect, scaleFactor: scale)
            let directory  = Defaults[.screenshotsDirectory]
            createDirectoryIfNeeded(directory)

            let ctx = try await pipeline.run(
                preCapture: screenshot,
                outputs: [ClipboardOutput(), LocalFileOutput(directory: directory)]
            )

            thumbnail.show(image: image, savedAt: ctx.outputURLs.first)
            playShutterSound()

        } catch { showError(error) }
    }

    // MARK: - Full-screen flow

    private func runFullScreen() async {
        do {
            let shot = try await capturer.capture(mode: .fullScreen(displayID: CGMainDisplayID()))
            let directory = Defaults[.screenshotsDirectory]
            createDirectoryIfNeeded(directory)
            let ctx = try await pipeline.run(
                preCapture: shot,
                outputs: [ClipboardOutput(), LocalFileOutput(directory: directory)]
            )
            thumbnail.show(image: shot.image, savedAt: ctx.outputURLs.first)
            playShutterSound()
        } catch { showError(error) }
    }

    // MARK: - Helpers

    private func playShutterSound() {
        guard Defaults[.captureSoundEnabled] else { return }
        let name = Defaults[.captureSoundName]
        NSSound(named: name.isEmpty ? "Grab" : name)?.play()
    }

    private func showError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "Capture failed"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.runModal()
    }

    private func createDirectoryIfNeeded(_ url: URL) {
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }
}

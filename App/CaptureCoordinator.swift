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
/// Hotkey → Freeze screens → Overlay (region / window select)
///        → Annotation editor → Crop pre-captured image
///        → Pipeline (clipboard + save) → Thumbnail preview
/// ```
@MainActor
final class CaptureCoordinator: ObservableObject {

    // MARK: - Dependencies

    private let capturer  = Capturer()
    private let provider  = DisplayProvider()
    private let pipeline  = PipelineRunner()
    private let overlay   = OverlayWindowController()
    private let editor    = EditorWindowController()
    private let thumbnail = ThumbnailController()

    // MARK: - Public actions

    /// Full ShareX-style flow: freeze → overlay → editor → crop → pipeline → thumbnail.
    func captureWithOverlay() {
        Task { await runOverlayCapture() }
    }

    /// Quick full-screen capture (no overlay). Maps to ⌘⇧3 by default.
    func captureFullScreen() {
        Task { await runFullScreen() }
    }

    // MARK: - Overlay flow

    private func runOverlayCapture() async {
        do {
            // 1. Fetch displays + window list (for grid highlight)
            let (displays, scWindows) = try await provider.fetchContent()
            guard !displays.isEmpty else { return }

            // 2. Capture all displays → frozen backgrounds
            var backgrounds: [(frame: CGRect, image: CGImage)] = []
            for display in displays {
                let shot = try await capturer.capture(mode: .fullScreen(displayID: display.displayID))
                backgrounds.append((frame: display.frame, image: shot.image))
            }

            // 3. Show overlay, wait for user selection
            let result = await overlay.show(backgrounds: backgrounds, scWindows: scWindows)
            guard case .region(let screenRect) = result else { return }

            // 4. Find which display was selected and crop the corresponding frozen image
            guard let (displayFrame, displayImage) = backgrounds.first(where: {
                $0.frame.intersects(screenRect)
            }) else { return }

            let scale = displays.first(where: { $0.frame == displayFrame })?.backingScaleFactor ?? 2.0

            guard let cropped = cropImage(
                displayImage,
                to: screenRect,
                displayFrame: displayFrame,
                scaleFactor: scale
            ) else { return }

            // 4b. Open annotation editor
            let editorResult = await editor.show(image: cropped, scaleFactor: scale)
            guard case .saved(let annotated) = editorResult else { return }

            let screenshot = Screenshot(image: annotated, sourceRect: screenRect, scaleFactor: scale)

            // 5. Pipeline: clipboard + file
            let directory = Defaults[.screenshotsDirectory]
            createDirectoryIfNeeded(directory)
            let ctx = try await pipeline.run(
                preCapture: screenshot,
                outputs: [
                    ClipboardOutput(),
                    LocalFileOutput(directory: directory),
                ]
            )

            // 6. Thumbnail preview + sound
            thumbnail.show(image: annotated, savedAt: ctx.outputURLs.first)
            playShutterSound()

        } catch {
            showError(error)
        }
    }

    // MARK: - Full-screen flow

    private func runFullScreen() async {
        do {
            let shot = try await capturer.capture(mode: .fullScreen(displayID: CGMainDisplayID()))

            let directory = Defaults[.screenshotsDirectory]
            createDirectoryIfNeeded(directory)
            let ctx = try await pipeline.run(
                preCapture: shot,
                outputs: [
                    ClipboardOutput(),
                    LocalFileOutput(directory: directory),
                ]
            )
            thumbnail.show(image: shot.image, savedAt: ctx.outputURLs.first)
            playShutterSound()
        } catch {
            showError(error)
        }
    }

    // MARK: - Image cropping

    /// Crops a full-display CGImage to the user-selected screen rect.
    ///
    /// Coordinate conversion:
    /// - `screenRect` and `displayFrame` use AppKit screen coords (bottom-left origin, points).
    /// - CGImage origin is top-left, pixels.
    private func cropImage(
        _ image: CGImage,
        to screenRect: CGRect,
        displayFrame: CGRect,
        scaleFactor: CGFloat
    ) -> CGImage? {
        let localX  = screenRect.minX - displayFrame.minX
        let localY  = screenRect.minY - displayFrame.minY
        let flippedY = displayFrame.height - localY - screenRect.height

        let pixelRect = CGRect(
            x: localX   * scaleFactor,
            y: flippedY * scaleFactor,
            width:  screenRect.width  * scaleFactor,
            height: screenRect.height * scaleFactor
        )
        return image.cropping(to: pixelRect)
    }

    // MARK: - Sound

    private func playShutterSound() {
        guard Defaults[.captureSoundEnabled] else { return }
        let name = Defaults[.captureSoundName]
        NSSound(named: name.isEmpty ? "Grab" : name)?.play()
    }

    // MARK: - Helpers

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

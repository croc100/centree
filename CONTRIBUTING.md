# Contributing to Reticle

Thanks for your interest in contributing! Here's everything you need to get started.

## Before you open a PR

- **Bug fix or small improvement?** Go ahead and open a PR — no prior issue needed.
- **New feature or significant change?** Open an issue first so we can discuss the design before you invest time writing code.

## Development setup

**Requirements:** macOS 13+, Xcode 15+, Swift 5.9+

```bash
git clone https://github.com/croc100/Reticle.git
cd Reticle
open Package.swift          # opens in Xcode — select ReticleApp scheme
```

Or build from the command line:

```bash
swift build
swift test --parallel
```

**Linting:**

```bash
brew install swiftlint
swiftlint
```

## Project structure

```
Sources/
  ReticleCore/      — Shared models, Defaults keys, helpers
  ReticleCapture/   — ScreenCaptureKit wrapper
  ReticleOverlay/   — Freeze overlay + annotation toolbar (AppKit/SwiftUI)
  ReticleEffects/   — CoreImage blur, pixelate, mask rendering
  ReticleRecorder/  — SCStream → MP4/GIF encoder
  ReticlePipeline/  — After-capture task pipeline
  ReticleNaming/    — Filename token parser
  ReticleVision/    — Vision OCR + PII detection
  ReticleUploaders/ — Upload adapters (Imgur, S3, SFTP, custom HTTP)
  ReticleWorkflow/  — Workflow profiles and hotkey bindings
App/
  ReticleApp.swift  — @main, scene setup
  CaptureCoordinator.swift — Top-level capture flow
  MenuBarController.swift  — Menu bar UI
  SettingsView.swift       — Settings window
Tests/
  ...               — XCTest targets mirroring Sources/
```

## Code style

- Follow existing conventions — the codebase uses `SwiftLint` with the config in `.swiftlint.yml`.
- Use `@MainActor` for UI-touching code. Use Swift concurrency (`async/await`) rather than callbacks wherever possible.
- Prefer `Defaults[.key]` from the `Defaults` package for user preferences — do not use `UserDefaults` directly.
- Keep modules focused: `ReticleCore` must not import any module above it.

## Submitting a PR

1. Fork and create a feature branch: `git checkout -b feat/my-feature`
2. Make your changes. Keep commits atomic and well-described.
3. Run `swift build && swift test --parallel` — both must pass.
4. Push and open a PR against `main`. Fill in the PR template.
5. A maintainer will review within a few days.

## Permissions needed for manual testing

| Permission | Why |
|---|---|
| Screen Recording | Required for all capture functionality |
| Accessibility | Scroll capture and hotkey recording |

Grant both in **System Settings → Privacy & Security**.

## License

By contributing you agree that your code is licensed under the [Apache License 2.0](LICENSE).

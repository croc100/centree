<p align="center">
  <img src="Resources/logo.svg" width="128" alt="Centree" />
</p>

<h1 align="center">Centree</h1>

<p align="center">
  A free, open-source screenshot tool for macOS — built for people who take screenshots seriously.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS%2013%2B-blue" />
  <img src="https://img.shields.io/badge/swift-5.9%2B-orange" />
  <img src="https://img.shields.io/badge/license-AGPL--3.0-green" />
  <img src="https://img.shields.io/badge/status-alpha-yellow" />
</p>

<p align="center">
  <img src="docs/assets/demo.svg" alt="Centree in action — annotation toolbar with freeze overlay" width="100%" />
</p>

---

## Features

### Capture

| Feature | Status |
|---|:---:|
| Region capture (freeze + annotate) | ✅ |
| Full-screen capture | ✅ |
| Window capture (picker) | ✅ |
| Scrolling screenshot | ✅ |
| Last region repeat | ✅ |
| Saved regions | ✅ |
| Auto capture (interval) | ✅ |
| Capture delay (countdown) | ✅ |

### Annotation Tools

21 tools, ShareX-style toolbar that slides in from the top of the frozen screen.

| Tool | Status |
|---|:---:|
| Rectangle / Ellipse / Line / Arrow | ✅ |
| Freehand pen | ✅ |
| Text | ✅ |
| Step numbers | ✅ |
| Speech balloon | ✅ |
| Highlight | ✅ |
| Blur (Gaussian, live preview) | ✅ |
| Pixelate (live preview) | ✅ |
| Blackout | ✅ |
| Spotlight | ✅ |
| Magnify / Loupe | ✅ |
| Emoji / Sticker | ✅ |
| Mouse cursor stamp | ✅ |
| Image insert | ✅ |
| Crop | ✅ |
| Eraser | ✅ |
| Select / Move | ✅ |

### After Capture

| Action | Status |
|---|:---:|
| Copy to clipboard | ✅ |
| Save to file (configurable path + filename tokens) | ✅ |
| Desktop notification with thumbnail | ✅ |
| OCR — extract text via Vision framework | ✅ |
| Pin to screen (floating image overlay) | ✅ |
| Open in viewer | ✅ |
| Reveal in Finder | ✅ |
| Copy file path | ✅ |

### Utilities

| Tool | Status |
|---|:---:|
| Screen color picker (loupe + HEX copy) | ✅ |
| Clipboard history (⌘⇧V, last 30 items) | ✅ |
| OCR result panel | ✅ |
| Customizable hotkeys | ✅ |

---

## Coming Soon

### Cloud Uploads
- Imgur
- Amazon S3 / Backblaze B2 / Cloudflare R2
- Google Drive / Dropbox
- FTP / SFTP
- Custom HTTP uploader (JSON-defined)
- URL shortener (bit.ly / is.gd)

### More Tools
- QR code generate / scan
- Screen recording — GIF & MP4
- Watch folder (auto-process on save)

### Centree-only
- **Static Mask** — register regions once, auto-redact on every capture
- **Vision PII detection** — auto-detect emails, phone numbers, API keys, JWTs

### Distribution
- Signed DMG + Apple notarization
- Homebrew Cask (`brew install --cask centree`)
- Sparkle auto-update

---

## Why Centree?

| | Centree | CleanShot X | Shottr | Flameshot |
|---|:---:|:---:|:---:|:---:|
| ShareX-style annotation toolbar | ✅ | ❌ | ❌ | ❌ |
| Blur / pixelate with live preview | ✅ | ✅ | ✅ | ✅ |
| Scrolling screenshot | ✅ | ✅ | ❌ | ❌ |
| Color picker | ✅ | ✅ | ✅ | ❌ |
| Clipboard history | ✅ | ✅ | ❌ | ❌ |
| OCR | ✅ | ✅ | ✅ | ❌ |
| Pin to screen | ✅ | ✅ | ❌ | ❌ |
| **Static Mask (auto-redact)** | 🔜 | ❌ | ❌ | ❌ |
| **Vision PII auto-detection** | 🔜 | ❌ | ❌ | ❌ |
| Open source | ✅ | ❌ | ❌ | ✅ |
| Free | ✅ | ❌ ($29) | ✅ | ✅ |

---

## Requirements

- macOS 13 Ventura or later
- Apple Silicon or Intel

## Installation

> Signed DMG and Homebrew coming with v1.0. Build from source until then.

```bash
git clone https://github.com/croc100/centree.git
cd centree
# Open Package.swift in Xcode → select CentreeApp scheme → Run
```

Grant **Screen Recording** permission on first launch.
Grant **Accessibility** permission for scroll capture and hotkey recording.

---

## Architecture

```
CentreeApp          — Menu bar app, hotkey wiring, capture coordinator
├── CentreeCapture  — ScreenCaptureKit wrapper (region / window / full-screen / scroll)
├── CentreeOverlay  — Full-screen freeze overlay + annotation toolbar (SwiftUI + AppKit)
├── CentreeEffects  — CoreImage blur / pixelate / mask rendering
├── CentreePipeline — Capture → AfterCapture → Output → AfterOutput task chain
├── CentreeNaming   — Filename token parser (%year%, %counter%, %app%, …)
├── CentreeVision   — Vision framework OCR + PII detector
├── CentreeWorkflow — Hotkey → workflow profile binding
├── CentreeUploaders— Upload adapters (Imgur, S3, custom HTTP, …)
└── CentreeCore     — Shared models, protocols, Defaults keys
```

---

## License

[GNU Affero General Public License v3.0](LICENSE)

Free for open-source use. Commercial use without AGPL compliance requires a separate license.

## Contributing

PRs welcome. Open an issue first for large changes.

© Centree Contributors

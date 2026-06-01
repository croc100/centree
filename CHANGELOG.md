# Changelog

All notable changes to Reticle are documented here.

---

## [0.1.0] — 2026-06-01

First public alpha release.

### Capture
- Region capture with freeze overlay — drag or click a window to capture instantly (ShareX-style)
- Full-screen capture (main display or per-monitor)
- Window picker — click any window to capture it
- Scrolling screenshot via Accessibility + CGEvent scroll
- Last region repeat
- User-saved named regions
- Auto capture on interval timer
- Capture delay with countdown overlay
- Default global shortcut: **⌘⇧2** (sits next to macOS built-ins ⌘⇧3/4)

### Annotation (21 tools)
Rectangle · Ellipse · Line · Arrow · Freehand pen · Freehand arrow · Text ·
Step numbers · Speech balloon · Highlight · Blur · Pixelate · Blackout ·
Spotlight · Magnify · Emoji · Cursor stamp · Image insert · Ruler · Crop · Eraser · Select/Move

All tools are **sticky** — stay active until you switch.  
Blur and Pixelate show a live preview.

### After Capture
- Copy to clipboard
- Save to file with filename token patterns (`%year%`, `%counter%`, `%app%`, …)
- Desktop notification with thumbnail
- OCR via Vision framework
- Pin to screen (floating overlay)
- Reveal in Finder · Copy file path · Open in Preview

### Upload Destinations
- Imgur (anonymous upload)
- Amazon S3 / Backblaze B2 / Cloudflare R2
- SFTP
- Custom HTTP endpoint (configurable method, field, headers, response path)

### Screen Recording _(new in 0.1.0)_
- MP4 (H.264, configurable FPS, 8 Mbps)
- Animated GIF (auto-downscale to 1280 px, 30 s cap, loops forever)
- Menu bar timer — live elapsed time while recording
- Auto-stop when GIF frame limit is reached

### Utilities
- Screen color picker with loupe and HEX copy
- Clipboard history (⌘⇧V, last 30 items)
- Workflow profiles — bind one hotkey to a full capture → output chain
- Customisable global hotkeys for all capture modes

### Distribution
- Available via **Homebrew**: `brew tap croc100/reticle && brew install --cask reticle`
- Ad-hoc signed DMG attached to this release
- Apache 2.0 licence — free to use, modify, and distribute

### Known limitations
- App is not notarised — first launch requires right-click → Open (or `xattr -dr com.apple.quarantine /Applications/Reticle.app`)
- Screen recording is in early state — multi-monitor region recording may produce unexpected crops
- No auto-update yet (Sparkle planned for v1.0)
- Google Drive / Dropbox upload not yet implemented

---

_Older entries will appear here as new versions are released._

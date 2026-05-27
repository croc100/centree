<p align="center">
  <img src="docs/assets/icon.png" width="128" alt="Centree icon" />
</p>

<h1 align="center">Centree</h1>

<p align="center">
  Open-source, redaction-first screenshot tool for macOS. Inspired by ShareX.
</p>

<p align="center">
  <a href="#english">English</a> ·
  <a href="#한국어">한국어</a> ·
  <a href="#中文">中文</a> ·
  <a href="#日本語">日本語</a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS%2013%2B-blue" />
  <img src="https://img.shields.io/badge/license-AGPL--3.0-green" />
  <img src="https://img.shields.io/badge/swift-5.9%2B-orange" />
  <img src="https://img.shields.io/badge/status-alpha-yellow" />
</p>

---

## English

### What is Centree?

Centree is a free, open-source macOS screenshot tool designed with **redaction first**. Instead of blurring sensitive areas after every capture, Centree lets you define mask regions once — they apply automatically on every screenshot.

Built for developers, tutorial creators, and anyone who takes the same screenshot repeatedly.

### Why Centree?

| Feature | Centree | CleanShot X | Shottr | Flameshot |
|---|:---:|:---:|:---:|:---:|
| Region / window / full-screen capture | ✅ | ✅ | ✅ | ✅ |
| ShareX-style inline annotation toolbar | ✅ | ❌ | ❌ | ❌ |
| Blur & pixelate (live preview) | ✅ | ✅ | ✅ | ✅ |
| Clipboard history (⌘⇧V) | ✅ | ✅ | ❌ | ❌ |
| Customizable hotkeys | ✅ | ✅ | ❌ | ✅ |
| **Static Mask (auto-redact per session)** | 🔜 | ❌ | ❌ | ❌ |
| **Vision PII auto-detection** | 🔜 | ❌ | ❌ | ❌ |
| Open source | ✅ | ❌ | ❌ | ✅ |
| Free | ✅ | ❌($29) | ✅ | ✅ |

### Current Features (v0.2)

- **ShareX-style capture** — global hotkeys, screen freeze, window detection
- **Inline annotation toolbar** — slides in from top with spring animation, notch-safe
- **13 annotation tools** — Rectangle, Ellipse, Line, Arrow, Freehand, Text, Step numbers, Highlight, **Blur**, **Pixelate**, Blackout, Select, Move
- **Live blur / pixelate preview** — CoreImage GPU-accelerated, drag to cover sensitive areas
- **Clipboard history** — ⌘⇧V panel, last 30 text & image items, search, re-copy
- **Customizable hotkeys** — Settings → Hotkeys, click to record new combo
- **Configurable output** — save path, filename token pattern (`%year%-%month%-%day%_%counter%.png`)
- **Clipboard + local save** — auto-copy to clipboard on every capture

### Requirements

- macOS 13 Ventura or later
- Apple Silicon or Intel Mac

### Installation

> Signed DMG and Homebrew formula coming with v1.0. Until then, build from source.

```bash
git clone https://github.com/croc100/centree.git
cd centree
# Open Package.swift in Xcode, select CentreeApp scheme, Run
```

### Roadmap

| Version | Focus |
|---|---|
| **v0.2** ✅ | ShareX-style toolbar, blur/pixelate, clipboard history, hotkey settings |
| **v0.3** | Static Mask (auto-redact), Vision PII detection, Live Mask |
| **v0.4** | Scrolling capture, upload integrations (Imgur, S3), workflow profiles |
| **v1.0** | Apple notarization, signed DMG, Homebrew, auto-update (Sparkle) |

### License

[GNU AGPL v3.0](LICENSE) — free for open-source use.
Commercial use without AGPL compliance requires a separate license.

### Contributing

PRs welcome. See [CONTRIBUTING.md](CONTRIBUTING.md).

---

## 한국어

### Centree란?

Centree는 **Redaction-first** 를 핵심으로 설계된 macOS용 무료 오픈소스 스크린샷 도구입니다. 매번 민감한 영역을 직접 블러 처리하는 대신, 마스크 영역을 한 번만 등록하면 이후 캡처마다 자동으로 적용됩니다.

개발자, 튜토리얼 제작자, 같은 화면을 반복해서 캡처하는 모든 분들을 위해 만들었습니다.

### 왜 Centree인가?

| 기능 | Centree | CleanShot X | Shottr | Flameshot |
|---|:---:|:---:|:---:|:---:|
| 영역 / 창 / 전체 화면 캡처 | ✅ | ✅ | ✅ | ✅ |
| ShareX 방식 인라인 어노테이션 툴바 | ✅ | ❌ | ❌ | ❌ |
| 블러 & 픽셀레이트 (실시간 미리보기) | ✅ | ✅ | ✅ | ✅ |
| 클립보드 히스토리 (⌘⇧V) | ✅ | ✅ | ❌ | ❌ |
| 단축키 커스텀 | ✅ | ✅ | ❌ | ✅ |
| **Static Mask (자동 마스크)** | 🔜 | ❌ | ❌ | ❌ |
| **Vision PII 자동 감지** | 🔜 | ❌ | ❌ | ❌ |
| 오픈소스 | ✅ | ❌ | ❌ | ✅ |
| 무료 | ✅ | ❌($29) | ✅ | ✅ |

### 현재 기능 (v0.2)

- **ShareX 방식 캡처** — 전역 단축키, 화면 프리즈, 윈도우 자동 감지
- **인라인 어노테이션 툴바** — 위에서 스프링 애니메이션으로 슬라이드 인, 노치 디스플레이 대응
- **13가지 어노테이션 도구** — 사각형, 타원, 선, 화살표, 펜, 텍스트, 스텝 번호, 하이라이트, **블러**, **픽셀레이트**, 블랙아웃, 선택, 이동
- **블러 / 픽셀레이트 실시간 미리보기** — CoreImage GPU 가속, 드래그로 민감 영역 가리기
- **클립보드 히스토리** — ⌘⇧V 패널, 텍스트·이미지 최근 30개, 검색, 재복사
- **단축키 커스텀** — 설정 → Hotkeys, 클릭 후 키 누르면 등록
- **출력 설정** — 저장 경로, 파일명 토큰 패턴 (`%year%-%month%-%day%_%counter%.png`)
- **클립보드 + 로컬 저장** — 캡처마다 자동 클립보드 복사

### 시스템 요구사항

- macOS 13 Ventura 이상
- Apple Silicon 또는 Intel Mac

### 설치

> 서명된 DMG와 Homebrew는 v1.0 출시 후 제공 예정. 현재는 소스 빌드만 가능합니다.

```bash
git clone https://github.com/croc100/centree.git
cd centree
# Xcode에서 Package.swift 열기 → CentreeApp 스킴 선택 → 실행
```

### 라이선스

[GNU AGPL v3.0](LICENSE) — 오픈소스 프로젝트는 무료로 사용 가능합니다.
AGPL 조건 없이 상업적으로 사용하려면 별도 라이선스가 필요합니다.

---

## 中文

### Centree 是什么？

Centree 是一款以 **隐私优先** 为核心设计理念的 macOS 开源截图工具。与其他工具不同，Centree 允许你预先定义遮罩区域，之后每次截图都会自动应用，无需每次手动打码。

专为开发者、教程制作者和需要重复截取相同画面的用户而设计。

### 为什么选择 Centree？

| 功能 | Centree | CleanShot X | Shottr | Flameshot |
|---|:---:|:---:|:---:|:---:|
| 区域 / 窗口 / 全屏截图 | ✅ | ✅ | ✅ | ✅ |
| ShareX 风格内联标注工具栏 | ✅ | ❌ | ❌ | ❌ |
| 模糊 & 马赛克（实时预览） | ✅ | ✅ | ✅ | ✅ |
| 剪贴板历史（⌘⇧V） | ✅ | ✅ | ❌ | ❌ |
| 自定义快捷键 | ✅ | ✅ | ❌ | ✅ |
| **静态遮罩（自动打码）** | 🔜 | ❌ | ❌ | ❌ |
| **Vision PII 自动检测** | 🔜 | ❌ | ❌ | ❌ |
| 开源 | ✅ | ❌ | ❌ | ✅ |
| 免费 | ✅ | ❌($29) | ✅ | ✅ |

### 当前功能（v0.2）

- **ShareX 风格截图** — 全局快捷键、画面冻结、窗口自动检测
- **内联标注工具栏** — 从顶部弹入（弹簧动画），支持刘海屏
- **13 种标注工具** — 矩形、椭圆、直线、箭头、画笔、文字、步骤编号、高亮、**模糊**、**马赛克**、黑色遮挡、选择、移动
- **模糊 / 马赛克实时预览** — CoreImage GPU 加速，拖拽即可遮挡敏感区域
- **剪贴板历史** — ⌘⇧V 面板，最近 30 条文字和图片记录，支持搜索与重新复制
- **自定义快捷键** — 设置 → Hotkeys，点击后按下新组合键即可绑定
- **输出配置** — 保存路径、文件名模板（`%year%-%month%-%day%_%counter%.png`）

### 系统要求

- macOS 13 Ventura 或更高版本
- Apple Silicon 或 Intel Mac

### 安装

> 已签名的 DMG 和 Homebrew 支持将在 v1.0 发布后提供，目前请从源码构建。

```bash
git clone https://github.com/croc100/centree.git
cd centree
# 用 Xcode 打开 Package.swift → 选择 CentreeApp Scheme → 运行
```

### 许可证

[GNU AGPL v3.0](LICENSE) — 开源项目可免费使用。
商业使用如需绕过 AGPL 条款，请联系获取商业许可证。

---

## 日本語

### Centree とは？

Centree は **プライバシーファースト** を核心に設計された macOS 向け無料オープンソーススクリーンショットツールです。毎回手動でぼかし処理をするのではなく、マスク領域を一度登録すれば以降のキャプチャに自動適用されます。

開発者、チュートリアル作成者、同じ画面を繰り返しキャプチャするすべての方のために作られました。

### なぜ Centree？

| 機能 | Centree | CleanShot X | Shottr | Flameshot |
|---|:---:|:---:|:---:|:---:|
| 領域 / ウィンドウ / 全画面キャプチャ | ✅ | ✅ | ✅ | ✅ |
| ShareX 方式インライン注釈ツールバー | ✅ | ❌ | ❌ | ❌ |
| ぼかし & モザイク（リアルタイムプレビュー） | ✅ | ✅ | ✅ | ✅ |
| クリップボード履歴（⌘⇧V） | ✅ | ✅ | ❌ | ❌ |
| カスタムホットキー | ✅ | ✅ | ❌ | ✅ |
| **スタティックマスク（自動マスク）** | 🔜 | ❌ | ❌ | ❌ |
| **Vision PII 自動検出** | 🔜 | ❌ | ❌ | ❌ |
| オープンソース | ✅ | ❌ | ❌ | ✅ |
| 無料 | ✅ | ❌($29) | ✅ | ✅ |

### 現在の機能（v0.2）

- **ShareX 方式キャプチャ** — グローバルホットキー、画面フリーズ、ウィンドウ自動検出
- **インライン注釈ツールバー** — 上部からスプリングアニメーションでスライドイン、ノッチ対応
- **13 種類の注釈ツール** — 矩形、楕円、直線、矢印、フリーハンド、テキスト、ステップ番号、ハイライト、**ぼかし**、**モザイク**、黒塗り、選択、移動
- **ぼかし / モザイクのリアルタイムプレビュー** — CoreImage GPU 加速、ドラッグで敏感な領域を隠す
- **クリップボード履歴** — ⌘⇧V パネル、テキスト・画像の最新 30 件、検索、再コピー
- **ホットキーのカスタマイズ** — 設定 → Hotkeys、クリック後にキーを押して登録
- **出力設定** — 保存先パス、ファイル名トークンパターン（`%year%-%month%-%day%_%counter%.png`）

### システム要件

- macOS 13 Ventura 以降
- Apple Silicon または Intel Mac

### インストール

> 署名済み DMG と Homebrew は v1.0 リリース後に提供予定です。現在はソースビルドのみ対応しています。

```bash
git clone https://github.com/croc100/centree.git
cd centree
# Xcode で Package.swift を開く → CentreeApp スキームを選択 → 実行
```

### ライセンス

[GNU AGPL v3.0](LICENSE) — オープンソースプロジェクトは無料で使用可能です。
AGPL 条件なしで商用利用する場合は、別途ライセンスが必要です。

---

## Architecture

```
CentreeApp (executable)
├── CentreeCapture    — ScreenCaptureKit wrapper
├── CentreeOverlay    — Overlay window + inline annotation toolbar
├── CentreeEffects    — CoreImage blur / pixelate / mask rendering
├── CentreePipeline   — Capture → AfterCapture → Output → AfterOutput
├── CentreeNaming     — Filename token parser (%year%, %counter%, …)
├── CentreeVision     — Vision framework PII detector (planned)
├── CentreeWorkflow   — Hotkey → workflow profile binding
├── CentreeUploaders  — Upload adapters: Imgur, S3, custom URL (planned)
└── CentreeCore       — Shared models, protocols, Defaults keys
```

## Contributing

PRs are welcome. Please read [CONTRIBUTING.md](CONTRIBUTING.md) first.

## License

[GNU Affero General Public License v3.0](LICENSE)

Free for open-source use. For commercial use without AGPL compliance, contact for a commercial license.

© Centree Contributors

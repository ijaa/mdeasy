# mdeasy

Tiny **offline Markdown reader** for macOS — full pack with **Mermaid**.

> Small · Fast · No account · No network · Focus on reading

Inspired by [MDView](https://www.mdview.cn/).

## Features (v0.2 full)

- Open / drag-drop / **double-click** `.md` (default handler)
- GFM: tables, task lists, auto-links
- **Mermaid** diagrams (bundled, offline, lazy-loaded)
- Live reload when the file changes on disk
- Outline (H1–H3)
- Themes: Light / Dark / Sepia / Green
- Local images (sandboxed to the markdown folder)
- Export HTML (includes rendered Mermaid SVG when possible)
- Fully offline — no telemetry

## Install (self-use, unsigned)

1. Download **`mdeasy.app`** or **`.dmg`** from [Releases](https://github.com/ijaa/mdeasy/releases) / Actions artifacts  
2. Drag `mdeasy.app` to **Applications** (recommended)  
3. First open — **System Settings → Privacy & Security → Open Anyway**  
4. Set as default Markdown app (pick one):

### A. In app (recommended)

**mdeasy → Set as Default Markdown App…**

### B. Finder Get Info (always works)

1. Select any `.md` file  
2. **File → Get Info** (`⌘I`)  
3. **Open with → mdeasy → Change All…**

Then double-click any Markdown file to open in mdeasy.

## Requirements

- macOS 12+
- Reader UI dev: Node.js 18+
- Building `.app`: Xcode on CI (`macos-14`); not required on your laptop

## Quick start (reader only)

```bash
cd reader
npm ci
npm run build
npm run preview
```

## Build app (machine with Xcode)

```bash
./scripts/build-reader.sh
./scripts/sync-reader-to-app.sh
./scripts/ci-xcodebuild.sh
# → build/mdeasy.app

VERSION=0.2.0 ./scripts/package-dmg.sh
# → build/mdeasy-0.2.0.dmg
```

Or push / tag on GitHub — Actions builds the unsigned app / release dmg.

## First open (unsigned)

1. Open `mdeasy` (if blocked, dismiss the alert)  
2. **System Settings → Privacy & Security**  
3. Click **Open Anyway** for mdeasy  

## Repository layout

```
App/                 Swift + WKWebView shell
reader/              Static reader (esbuild + markdown-it + mermaid)
scripts/             build / sync / xcodebuild / dmg
fixtures/            sample markdown
.github/workflows/   CI + Release
docs/技术方案.md
```

## License

MIT (see [LICENSE](LICENSE))

# mdeasy

Tiny **offline Markdown reader** for macOS.

> Small · Fast · No account · No network · Focus on reading

Inspired by [MDView](https://www.mdview.cn/).

## Features (v0.1)

- Open / drag-drop / file association for `.md`
- GFM: tables, task lists, strikethrough-friendly CommonMark
- Live reload when the file changes on disk
- Outline (H1–H3)
- Themes: Light / Dark / Sepia / Green
- Local images (sandboxed to the markdown folder)
- Export HTML
- Fully offline — no telemetry

Mermaid is **not** bundled in the basic pack (placeholder shown). Optional full pack later.

## Requirements

- macOS 12+
- For **development of the reader UI**: Node.js 18+
- For **building the .app**: Xcode (on GitHub Actions `macos-14`; not required on your laptop)

## Quick start (reader only, no Xcode)

```bash
cd reader
npm ci
npm run build
npm run preview   # browser preview of the renderer
```

## Build app (machine with Xcode)

```bash
./scripts/build-reader.sh
./scripts/sync-reader-to-app.sh
./scripts/ci-xcodebuild.sh
# → build/mdeasy.app

./scripts/package-dmg.sh
# → build/mdeasy-0.1.0.dmg
```

Or push to GitHub — **Actions** builds an unsigned `.app` artifact.

## First open (unsigned self-use build)

This project ships **without** Apple Developer signing (no annual fee).

1. Open `mdeasy` (if macOS blocks it, dismiss the alert)
2. Open **System Settings → Privacy & Security**
3. Scroll to the security section — you should see that **mdeasy** was blocked
4. Click **Open Anyway**, then confirm **Open**

On the same Mac, later launches are usually normal.

## Repository layout

```
App/                 Swift + WKWebView shell + Xcode project
reader/              Static reader (esbuild + markdown-it)
scripts/             build / sync / xcodebuild / dmg
fixtures/            sample markdown
.github/workflows/   CI + Release
docs/技术方案.md      design notes
```

## License

MIT (see [LICENSE](LICENSE))

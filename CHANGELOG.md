# Changelog

All notable changes to MDEye will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.7.1] - 2026-07-22

### Added
- Menu bar localization support (Simplified Chinese and English)
- Export icon (⬇) to PDF button for better visual clarity
- Pre-release documentation checklist in CLAUDE.md and AGENTS.md

### Changed
- Menu language now follows system language automatically
- PDF button now has a visual export icon

### Fixed
- Localization resources path issue (moved from nested Resources/Resources/ to correct Resources/)

## [0.7.0] - 2024-12-XX

### Added
- Font size scaling (⌘+/⌘-/⌘0, 85%–200%)
- Content width adjustment (⌥+/⌥-, 600–1100px)
- KaTeX math formulas support ($inline$ and $$display$$, offline)
- In-document search (⌘F/⌘G/⇧⌘G)
- Cold-start restore last opened file
- GB18030 Chinese encoding support
- Rich text detection with toast notification

### Changed
- Open in Editor now defaults to TextEdit
- Print behavior: screen zoom settings don't affect PDF output

## [0.6.0] - 2024-11-XX

### Added
- Quick PDF export from toolbar
- Sepia theme as default
- Export PDF menu item

### Changed
- Improved PDF export quality and pagination

## Earlier versions

See [Releases](https://github.com/ijaa/mdeye/releases) for earlier version history.

# UMLExpress

Native macOS UML editor — a Swift port of [JetUML](https://github.com/prmr/JetUML) 3.10.

- Minimum OS: **macOS 26.0** (`platforms: [.macOS(.v26)]`)
- Language: Swift 6, no third-party dependencies
- Licensed under **GPL-3** as a derivative work of JetUML; see [`LICENSE`](LICENSE) and
  [`NOTICE`](NOTICE)

## Features

* All five diagram types of JetUML: **class**, **sequence**, **state**, **object** and
  **use case** diagrams.
* Reads and writes JetUML's `.jet` files (schema 3.0), so files can be exchanged with the
  Java application.
* Drag-and-drop editing with a tool palette whose icons are drawn by the element
  renderers, undo/redo, clipboard, (multi-)selection with handles, lasso selection.
* Property sheet with live editing and one undo step per editing session.
* Native window tabs, dark mode, zoom, welcome window with recent files.
* Export to **SVG**, **PNG** and **PDF**, or copy the diagram to the clipboard.
* Renders through an abstract context, which also produces the tool icons and the exported
  files with the same code that paints the canvas.

## Status

All milestones (M0–M10) are done: **457 tests, all green**. Every diagram type loads from
real JetUML files, validates, edits with undo/redo, renders and exports; the application is
packaged as a signed `.app` bundle. Acceptance results are in
[`PARITY-MATRIX.md`](PARITY-MATRIX.md).

| Module | Contents |
|---|---|
| `UMLGeometry` | points, lines, rectangles, directions, grid and geometry helpers |
| `UMLModel` | 19 node types, 15 edge types, `Properties`, `Diagram`, `Prototypes` |
| `UMLRendering` | SVG + Core Graphics + PDF contexts, text metrics, `ColorScheme`, renderers for all five diagram types, edge routing, icon generation |
| `UMLPersistence` | `.jet` decoding, encoding and validation on load |
| `UMLValidation` | violations, constraints, one validator per diagram type |
| `UMLOperations` | diagram operations, undo/redo, one builder per diagram type |
| `UMLInteraction` | canvas controller, move tracker, clipboard, property-sheet model |
| `UMLStudio` | AppKit layer: canvas view, window controller, documents, property sheet, welcome window, recent files, menus, exporter |
| `UMLExpressApp` | application entry point (opens files from `argv` and the Finder) |

## Build & test

Normal usage (Xcode 26.x selected, plain terminal, CI):

```sh
swift build
swift test
```

Inside a restricted sandbox (e.g. an agent harness) SwiftPM's nested `sandbox-exec`
is not permitted, so use project-local caches and disable it:

```sh
env TMPDIR="$PWD/.build/tmp" \
    CLANG_MODULE_CACHE_PATH="$PWD/.build/mc" \
    SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/mc" \
    swift test --disable-sandbox --scratch-path "$PWD/.build"
```

## Installation

Download `UMLExpress-<version>.zip` from the
[releases page](https://github.com/kabanetsa/umlexpress/releases), unpack it and move
`UMLExpress.app` to your Applications folder.

Requirements: **macOS 26.0 or later**. The bundle is a universal binary (Apple Silicon and
Intel).

> The application is signed **ad-hoc**, not with a Developer ID, and it is not notarised.
> The first launch therefore needs a confirmation: right-click (or Control-click) the app
> and choose **Open**, or remove the quarantine flag once:
>
> ```sh
> xattr -dr com.apple.quarantine /Applications/UMLExpress.app
> ```

Diagrams are saved as `.jet` files, the same format JetUML 3.10 uses, so files can be
exchanged with the Java application.

## Build the application bundle

```sh
./Scripts/build-app.sh                 # universal binary, app bundle, ZIP, DMG if possible
./Scripts/build-app.sh --native        # only the architecture of this machine
./Scripts/build-app.sh --no-dmg        # skip the disk image
```

The script builds the release binary, generates the icon, writes the `Info.plist`
(including the `jet` document type), ad-hoc signs the bundle, and writes
`build/UMLExpress-<version>.zip` next to a `.sha256` checksum; it also creates a DMG when
the system lets `hdiutil` run (it needs access to disk-image devices, which some sandboxes
deny). Distribution through the App Store or without the first-launch confirmation needs a
Developer ID certificate and notarisation.

## Repository layout

```
Package.swift              Swift package (9 modules + the application)
Sources/                   the modules listed above
Tests/                     unit, integration and acceptance tests
Samples/                   rendered diagrams and a JetUML fixture
Scripts/                   build-app.sh, make-icon.swift
PARITY-MATRIX.md           what is ported, what is not, and known deviations
```

## Licensing

UMLExpress is a derivative work of JetUML 3.10, Copyright (C) 2012–2025 McGill
University, and is distributed under the GNU General Public License, version 3. Every
source file that contains ported code names the original class in its header; see
[`NOTICE`](NOTICE) for the details. There is no warranty of any kind.

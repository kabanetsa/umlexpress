//
//  PaletteIconTests.swift
//  UMLExpress
//
//  Checks that every palette entry of every diagram type has an icon, that the action
//  icons are bundled, and that the window actually puts the icons on the buttons.
//

import AppKit
import CoreGraphics
import Testing
import UMLGeometry
import UMLModel
import UMLRendering
@testable import UMLStudio

/// The icons drawn by the element renderers for the tool palette.
@MainActor
struct PaletteIconTests {

    /// All prototypes of all diagram types.
    private static var allPrototypes: [(DiagramKind, any DiagramElement)] {
        DiagramKind.allCases.flatMap { kind in kind.prototypes.map { (kind, $0) } }
    }

    @Test func everyToolHasAnIcon() {
        for (kind, prototype) in Self.allPrototypes {
            let renderer = DiagramRendererFactory.renderer(for: Diagram(kind: kind))
            let icon = renderer.icon(of: prototype)
            #expect(icon != nil, "no icon for \(type(of: prototype)) (\(kind))")
        }
    }

    @Test func iconsHaveTheExpectedSize() {
        for (kind, prototype) in Self.allPrototypes {
            let renderer = DiagramRendererFactory.renderer(for: Diagram(kind: kind))
            guard let icon = renderer.icon(of: prototype) else { continue }
            #expect(icon.width == IconRendering.buttonSize * IconRendering.scaleFactor)
            #expect(icon.height == IconRendering.buttonSize * IconRendering.scaleFactor)
        }
    }

    /// An icon that draws nothing at all would be an invisible button.
    @Test func iconsAreNotBlank() {
        for (kind, prototype) in Self.allPrototypes {
            let renderer = DiagramRendererFactory.renderer(for: Diagram(kind: kind))
            guard let icon = renderer.icon(of: prototype), let pixels = Self.pixels(of: icon) else {
                continue
            }
            let drawn = stride(from: 3, to: pixels.count, by: 4).count { pixels[$0] > 8 }
            #expect(drawn > 20, "the icon of \(type(of: prototype)) (\(kind)) is blank")
        }
    }

    /// The icon background is transparent, like the JavaFX canvas of the original.
    ///
    /// An opaque background shows as a square inside the highlighted bezel of the tool
    /// that is currently selected.
    @Test func iconsHaveATransparentBackground() {
        for (kind, prototype) in Self.allPrototypes {
            let renderer = DiagramRendererFactory.renderer(for: Diagram(kind: kind))
            guard let icon = renderer.icon(of: prototype), let pixels = Self.pixels(of: icon) else {
                continue
            }
            let transparent = stride(from: 3, to: pixels.count, by: 4).count { pixels[$0] == 0 }
            #expect(transparent > 0, "the icon of \(type(of: prototype)) (\(kind)) is opaque")
        }
        // The corner of a class icon is empty space: no full-size background square.
        let renderer = DiagramRendererFactory.renderer(for: Diagram(kind: .class))
        let classPrototype = DiagramKind.class.prototypes[0]
        guard let icon = renderer.icon(of: classPrototype), let pixels = Self.pixels(of: icon) else {
            Issue.record("no class icon")
            return
        }
        let corner = (1 * icon.width + 1) * 4 + 3
        #expect(pixels[corner] == 0)
    }

    /// Two tools of different kinds must not look the same, or the palette would be
    /// ambiguous. (The class diagram has two generalization prototypes, which do share a
    /// type and therefore an icon.)
    @Test func toolsOfDifferentTypesLookDifferent() {
        for kind in DiagramKind.allCases {
            let renderer = DiagramRendererFactory.renderer(for: Diagram(kind: kind))
            var seen: [String: Int] = [:]
            for prototype in kind.prototypes {
                let name = String(describing: type(of: prototype))
                guard let icon = renderer.icon(of: prototype), let pixels = Self.pixels(of: icon)
                else {
                    continue
                }
                let hash = pixels.reduce(17) { ($0 &* 31 &+ Int($1)) & 0xFFFFFF }
                if seen[name] == nil {
                    // Two prototypes of the same element type may differ (a composition
                    // and an aggregation arrow, for example), so only cross-type
                    // collisions are ambiguous.
                    let others = seen.filter { $0.key != name && $0.value == hash }
                    #expect(others.isEmpty,
                            "\(kind): \(name) draws the same icon as \(others.keys)")
                }
                seen[name] = hash
            }
            let types = Set(kind.prototypes.map { String(describing: type(of: $0)) })
            #expect(seen.count == types.count, "\(kind): \(seen.count) of \(types.count) types")
        }
    }

    /// The rasterized pixels of an image.
    private static func pixels(of image: CGImage) -> [UInt8]? {
        var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
        guard let context = CGContext(data: &bytes, width: image.width, height: image.height,
                                      bitsPerComponent: 8, bytesPerRow: image.width * 4,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else {
            return nil
        }
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return bytes
    }
}

/// The action icons copied from the original.
@MainActor
struct ActionIconTests {

    /// The names of the files shipped in `icons/16x16`.
    private static let iconNames = [
        "application-exit", "application-x-font-ttf", "camera-photo", "clock", "dark-mode",
        "document-close", "document-edit", "document-export", "document-new",
        "document-open-recent", "document-open", "document-properties", "document-save-as",
        "document-save", "documentation", "duplicate", "edit-copy", "edit-cut", "edit-delete",
        "edit-paste", "edit-redo", "edit-select-all", "edit-undo", "help-about", "help-hint",
        "jet", "view-grid", "zoom-fit-width", "zoom-in", "zoom-original", "zoom-out",
    ]

    @Test func actionIconsAreBundled() {
        for name in Self.iconNames {
            #expect(IconCatalog.image(named: name) != nil, "missing icon \(name)")
        }
    }

    @Test func actionIconsAreSixteenPixels() {
        guard let image = IconCatalog.image(named: "document-new") else {
            Issue.record("missing icon")
            return
        }
        #expect(image.size.width == 16)
        #expect(image.size.height == 16)
    }

    @Test func missingIconFallsBack() {
        #expect(IconCatalog.image(named: "not-an-icon") == nil)
        #expect(IconCatalog.image(named: "not-an-icon", fallback: "trash") != nil)
    }
}

/// The window-side integration: palette buttons carry the rendered icons.
@MainActor
struct ToolPaletteIconTests {

    @Test func paletteButtonsUseIcons() {
        let diagram = Diagram(kind: .class)
        let controller = DiagramWindowController(session: .init(diagram: diagram))
        let prototypes = DiagramKind.class.prototypes
        for prototype in prototypes {
            let icon = controller.toolIcon(for: prototype)
            #expect(icon != nil, "no icon for \(type(of: prototype))")
        }
        let buttons = controller.toolPaletteButtons()
        #expect(buttons.count == prototypes.count + 1)
        // Every button, the selection tool included, shows an image instead of text.
        for button in buttons {
            #expect(button.image != nil)
            #expect(button.title.isEmpty)
        }
        // The buttons are large enough for a 25-point icon. The size is asserted through
        // the constraints: a window that is never displayed does not run Auto Layout, so
        // its frames still hold the intrinsic sizes.
        for button in buttons {
            let widths = button.constraints.filter { $0.firstAttribute == .width }.map(\.constant)
            let heights = button.constraints.filter { $0.firstAttribute == .height }.map(\.constant)
            #expect(widths.contains(DiagramWindowController.toolButtonSize.width),
                    "the button must be \(DiagramWindowController.toolButtonSize.width) points wide")
            #expect(heights.contains(DiagramWindowController.toolButtonSize.height),
                    "the button must be \(DiagramWindowController.toolButtonSize.height) points high")
        }
    }
}

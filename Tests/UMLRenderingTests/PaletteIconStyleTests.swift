//
//  PaletteIconStyleTests.swift
//  UMLExpress
//
//  The palette can be drawn in several styles; these tests keep them apart and make sure
//  the switch really changes the painting.
//

import CoreGraphics
import XCTest
@testable import UMLGeometry
@testable import UMLModel
@testable import UMLRendering

final class PaletteIconStyleTests: XCTestCase {

    private func signature(_ style: PaletteIconStyle) -> (dark: Int, blue: Int) {
        IconStyleSettings.current = style
        defer { IconStyleSettings.current = .drafting }
        let renderer = DiagramRendererFactory.renderer(for: Diagram(kind: .class))
        var dark = 0
        var blue = 0
        for prototype in DiagramKind.class.prototypes {
            guard let icon = renderer.icon(of: prototype) else { continue }
            let width = icon.width
            let height = icon.height
            var pixels = [UInt8](repeating: 0, count: width * height * 4)
            let context = CGContext(data: &pixels, width: width, height: height,
                                    bitsPerComponent: 8, bytesPerRow: width * 4,
                                    space: CGColorSpaceCreateDeviceRGB(),
                                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            context.draw(icon, in: CGRect(x: 0, y: 0, width: width, height: height))
            for index in stride(from: 0, to: pixels.count, by: 4) where pixels[index + 3] > 16 {
                let red = Double(pixels[index])
                let green = Double(pixels[index + 1])
                let blueComponent = Double(pixels[index + 2])
                if red < 128, green < 128, blueComponent < 128 {
                    dark += 1
                }
                if blueComponent > red + 40, blueComponent > green + 20 {
                    blue += 1
                }
            }
        }
        return (dark, blue)
    }

    /// Every style draws something.
    func testEveryStyleDrawsIcons() {
        for style in PaletteIconStyle.allCases {
            let result = signature(style)
            XCTAssertGreaterThan(result.dark + result.blue, 100, "\(style) draws nothing")
        }
    }

    /// The styles are really different from each other.
    func testStylesDiffer() {
        let darkCounts = PaletteIconStyle.allCases.map { signature($0).dark }
        XCTAssertEqual(Set(darkCounts).count, darkCounts.count,
                       "every style must paint its own picture")
    }

    /// Only the accented style uses the accent colour.
    func testOnlyTheAccentedStyleIsBlue() {
        XCTAssertEqual(0, signature(.drafting).blue)
        XCTAssertEqual(0, signature(.wireframe).blue)
        XCTAssertEqual(0, signature(.monogram).blue)
        XCTAssertGreaterThan(signature(.accented).blue, 100)
    }

    /// The default style is the faithful portrait of the element.
    func testDefaultStyleIsDrafting() {
        XCTAssertEqual(.drafting, IconStyleSettings.current)
    }

    /// A monogram exists for every tool of every diagram type.
    func testEveryToolHasAMonogram() {
        for kind in DiagramKind.allCases {
            for prototype in kind.prototypes {
                let letter = IconStyleSettings.monogram(for: prototype)
                XCTAssertNotEqual("?", letter, "no monogram for \(type(of: prototype))")
                XCTAssertFalse(letter.isEmpty)
            }
        }
    }
}

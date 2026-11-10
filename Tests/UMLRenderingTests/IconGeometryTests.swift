//
//  IconGeometryTests.swift
//  UMLExpress
//
//  The icons are the elements drawn into a small canvas; the parts of an element have to
//  stay attached to each other when the drawing is rounded to whole pixels.
//

import CoreGraphics
import XCTest
@testable import UMLGeometry
@testable import UMLModel
@testable import UMLRendering

final class IconGeometryTests: XCTestCase {

    /// Rasterises an icon and returns the rows that contain any drawing.
    private func inkRows(of icon: CGImage) -> [Int] {
        var rows: [Int] = []
        let width = icon.width
        let height = icon.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(data: &pixels, width: width, height: height,
                                      bitsPerComponent: 8, bytesPerRow: width * 4,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else {
            return rows
        }
        context.draw(icon, in: CGRect(x: 0, y: 0, width: width, height: height))
        for y in 0..<height {
            for x in 0..<width where pixels[(y * width + x) * 4 + 3] > 16 {
                rows.append(y)
                break
            }
        }
        return rows
    }

    /// The tab of a package icon and its body share a border: there is no empty row
    /// between them, which would make the tab look like a separate square.
    func testPackageTabTouchesThePackageBody() throws {
        let renderer = DiagramRendererFactory.renderer(for: Diagram(kind: .class))
        let package = try XCTUnwrap(DiagramKind.class.prototypes.first { $0 is PackageNode })
        let icon = try XCTUnwrap(renderer.icon(of: package))
        let rows = inkRows(of: icon)
        XCTAssertGreaterThan(rows.count, 4)
        // Every row of the drawing is filled: no gap anywhere inside the icon.
        let first = try XCTUnwrap(rows.first)
        let last = try XCTUnwrap(rows.last)
        XCTAssertEqual(Array(first...last), rows,
                       "the icon must not have an empty row between its parts")
    }

    /// The description variant has the same folder outline as the plain package.
    func testPackageDescriptionTabTouchesTheBody() throws {
        let renderer = DiagramRendererFactory.renderer(for: Diagram(kind: .class))
        let description = try XCTUnwrap(DiagramKind.class.prototypes
            .first { $0 is PackageDescriptionNode })
        let icon = try XCTUnwrap(renderer.icon(of: description))
        let rows = inkRows(of: icon)
        let first = try XCTUnwrap(rows.first)
        let last = try XCTUnwrap(rows.last)
        XCTAssertEqual(Array(first...last), rows)
    }
}

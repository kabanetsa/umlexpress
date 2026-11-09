import CoreGraphics
import XCTest
@testable import UMLGeometry
@testable import UMLModel
@testable import UMLPersistence
@testable import UMLRendering

/// Tests for the Core Graphics rendering context: the primitives are verified by
/// inspecting the pixels of an off-screen bitmap.
final class CGRenderingContextTests: XCTestCase {

    /// A bitmap with a y-down coordinate system, matching an `NSView` with
    /// `isFlipped == true`.
    private final class Bitmap {
        let width: Int
        let height: Int
        let context: CGContext

        init(width: Int, height: Int, fill: RGBAColor = .white) {
            self.width = width
            self.height = height
            let space = CGColorSpaceCreateDeviceRGB()
            context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                bytesPerRow: width * 4, space: space,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            // Flip so that y grows downwards, like the JavaFX canvas.
            context.translateBy(x: 0, y: CGFloat(height))
            context.scaleBy(x: 1, y: -1)
            context.setFillColor(fill.cgColor)
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }

        /// The colour of one pixel, as (red, green, blue, alpha) in 0...255.
        ///
        /// The context is flipped so that drawing coordinates grow downwards; after the
        /// flip the buffer row index equals the drawing y.
        func pixel(_ x: Int, _ y: Int) -> (Int, Int, Int, Int) {
            let data = context.data!.assumingMemoryBound(to: UInt8.self)
            let offset = (y * width + x) * 4
            return (Int(data[offset]), Int(data[offset + 1]), Int(data[offset + 2]), Int(data[offset + 3]))
        }

        var darkPixels: Int {
            var count = 0
            for y in 0..<height {
                for x in 0..<width {
                    let (r, g, b, _) = pixel(x, y)
                    if r < 128 && g < 128 && b < 128 {
                        count += 1
                    }
                }
            }
            return count
        }

        /// Pixels that are not (almost) white, e.g. light grey shadow pixels.
        var nonWhitePixels: Int {
            var count = 0
            for y in 0..<height {
                for x in 0..<width {
                    let (r, g, b, _) = pixel(x, y)
                    if r < 250 || g < 250 || b < 250 {
                        count += 1
                    }
                }
            }
            return count
        }

        func png() throws -> Data {
            let image = context.makeImage()!
            let data = NSMutableData()
            let destination = CGImageDestinationCreateWithData(
                data, "public.png" as CFString, 1, nil)!
            CGImageDestinationAddImage(destination, image, nil)
            CGImageDestinationFinalize(destination)
            return data as Data
        }
    }

    func testStrokeLineDrawsPixels() {
        let bitmap = Bitmap(width: 60, height: 40)
        let context = CGRenderingContext(bitmap.context)
        context.strokeLine(10, 20, 50, 20, .black, .solid)
        XCTAssertGreaterThan(bitmap.darkPixels, 20, "the line must be visible")
        // A pixel far from the line stays white.
        let (r, g, b, _) = bitmap.pixel(10, 5)
        XCTAssertGreaterThan(r, 250)
        XCTAssertGreaterThan(g, 250)
        XCTAssertGreaterThan(b, 250)
    }

    func testDottedLineLeavesGaps() {
        let solid = Bitmap(width: 120, height: 20)
        CGRenderingContext(solid.context).strokeLine(10, 10, 110, 10, .black, .solid)

        let dotted = Bitmap(width: 120, height: 20)
        CGRenderingContext(dotted.context).strokeLine(10, 10, 110, 10, .black, .dotted)

        XCTAssertGreaterThan(solid.darkPixels, dotted.darkPixels,
                             "a dotted line must cover fewer pixels")
        XCTAssertGreaterThan(dotted.darkPixels, 0)
    }

    func testDrawRectangleFillsAndStrokes() {
        let bitmap = Bitmap(width: 100, height: 80)
        let context = CGRenderingContext(bitmap.context)
        context.drawRectangle(Rectangle(x: 20, y: 20, width: 40, height: 30),
                             fill: RGBAColor(255, 0, 0), stroke: .black, hasShadow: false)

        // Inside: the red fill (Core Graphics converts colours, so compare magnitudes).
        let (r, g, b, _) = bitmap.pixel(40, 35)
        XCTAssertGreaterThan(r, 200)
        XCTAssertLessThan(g, 100)
        XCTAssertLessThan(b, 100)

        // On the top edge: the black stroke (within a pixel or two of y = 20).
        let edge = (19...21).map { bitmap.pixel(40, $0) }
        XCTAssertTrue(edge.contains { $0.0 < 128 && $0.1 < 128 && $0.2 < 128 }, "the stroke is drawn")
    }

    func testDrawOvalAndRoundedRectangle() {
        let bitmap = Bitmap(width: 100, height: 100)
        let context = CGRenderingContext(bitmap.context)
        context.drawOval(10, 10, width: 40, height: 40, fill: RGBAColor(0, 0, 255),
                         stroke: .black, hasShadow: false)
        let (r, g, b, _) = bitmap.pixel(30, 30)
        XCTAssertLessThan(r, 100)
        XCTAssertLessThan(g, 100)
        XCTAssertGreaterThan(b, 200)

        let rounded = Bitmap(width: 100, height: 100)
        let roundedContext = CGRenderingContext(rounded.context)
        roundedContext.drawRoundedRectangle(Rectangle(x: 10, y: 10, width: 60, height: 40),
                                           fill: RGBAColor(0, 200, 0), stroke: .black, hasShadow: false)
        let (rr, rg, rb, _) = rounded.pixel(40, 30)
        XCTAssertLessThan(rr, 100)
        XCTAssertGreaterThan(rg, 150)
        XCTAssertLessThan(rb, 100)
        // The corners are rounded: the very corner stays white.
        let (cr, cg, cb, _) = rounded.pixel(10, 10)
        XCTAssertGreaterThan(cr, 200)
        XCTAssertGreaterThan(cg, 200)
        XCTAssertGreaterThan(cb, 200)
    }

    func testStrokePathAndClosedPath() {
        let bitmap = Bitmap(width: 80, height: 80)
        let context = CGRenderingContext(bitmap.context)
        let commands: [PathCommand] = [.move(to: Point(x: 10, y: 10)),
                                       .line(to: Point(x: 70, y: 10)),
                                       .line(to: Point(x: 70, y: 70)),
                                       .line(to: Point(x: 10, y: 70))]
        context.strokePath(commands, color: .black, style: .solid)
        XCTAssertGreaterThan(bitmap.darkPixels, 50)

        let filled = Bitmap(width: 80, height: 80)
        let filledContext = CGRenderingContext(filled.context)
        filledContext.drawClosedPath(commands, fill: RGBAColor(0, 0, 255), stroke: .black, hasShadow: false)
        let (r, g, b, _) = filled.pixel(40, 40)
        XCTAssertLessThan(r, 100)
        XCTAssertLessThan(g, 100)
        XCTAssertGreaterThan(b, 200)
    }

    func testDrawTextProducesInk() {
        let blank = Bitmap(width: 120, height: 40)
        let bitmap = Bitmap(width: 120, height: 40)
        let context = CGRenderingContext(bitmap.context)
        let style = TextStyle(family: "Helvetica", size: 14)
        let measurer = CoreTextMeasurer()
        let dimension = FontDimension(lineHeight: measurer.dimension(of: "|", style: style).height,
                                      baselineOffset: measurer.dimension(of: "|", style: style).height
                                          - measurer.baselineOffset(of: style))
        context.drawText("Hello", bounds: Rectangle(x: 5, y: 5, width: 100, height: dimension.lineHeight),
                         alignment: .left, color: .black, style: style, fontDimension: dimension)
        XCTAssertGreaterThan(bitmap.darkPixels, blank.darkPixels, "text must produce dark pixels")
    }

    func testShadowAddsGreyPixels() {
        let plain = Bitmap(width: 100, height: 100)
        CGRenderingContext(plain.context).drawRectangle(Rectangle(x: 10, y: 10, width: 50, height: 30),
                                                        fill: .white, stroke: .black, hasShadow: false)
        let shadowed = Bitmap(width: 100, height: 100)
        CGRenderingContext(shadowed.context).drawRectangle(Rectangle(x: 10, y: 10, width: 50, height: 30),
                                                           fill: .white, stroke: .black, hasShadow: true)
        XCTAssertGreaterThan(shadowed.nonWhitePixels, plain.nonWhitePixels,
                             "the shadow adds light grey pixels")
    }

    /// Renders a whole JetUML diagram into a bitmap: the end-to-end drawing path for the
    /// Canvas-based UI (M7).
    func testRenderDiagramToBitmap() throws {
        let path = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("UMLPersistenceTests/Fixtures/testPersistenceService.class.jet")
        let diagram = try DiagramCoding.decode(try Data(contentsOf: path))
        let renderer = ClassDiagramRenderer(diagram: diagram)
        let bounds = renderer.diagramBounds()

        let bitmap = Bitmap(width: bounds.width + 20, height: bounds.height + 20)
        let context = CGRenderingContext(bitmap.context)
        context.strokeLine(0, 0, 0, 0, .white, .solid) // anchor the translation
        renderer.draw(context)

        XCTAssertGreaterThan(bitmap.darkPixels, 500, "the diagram must be visible in the bitmap")

        // Write a PNG next to the sources for manual inspection.
        let directory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Samples")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try bitmap.png().write(to: directory.appendingPathComponent("jetumlFixtureDiagram.png"))
    }
}

/// Text orientation and placement in the Core Graphics context.
///
/// The rendering pipeline draws in a y-down (flipped) coordinate system, while CoreText lays
/// glyphs out in a y-up space. Without mirroring the text matrix, glyphs are drawn upside down
/// and appear one line too low — which is exactly "text in the wrong compartment".
final class CGTextRenderingTests: XCTestCase {

    /// A bitmap with a y-down coordinate system, as used by the canvas and the exporters.
    private final class Bitmap {
        let width: Int
        let height: Int
        let context: CGContext

        init(width: Int, height: Int) {
            self.width = width
            self.height = height
            let space = CGColorSpaceCreateDeviceRGB()
            context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                bytesPerRow: width * 4, space: space,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            context.translateBy(x: 0, y: CGFloat(height))
            context.scaleBy(x: 1, y: -1)
            context.setFillColor(RGBAColor.white.cgColor)
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }

        func isDark(_ x: Int, _ y: Int) -> Bool {
            let data = context.data!.assumingMemoryBound(to: UInt8.self)
            let offset = (y * width + x) * 4
            let r = Int(data[offset]), g = Int(data[offset + 1]), b = Int(data[offset + 2])
            return r < 160 && g < 160 && b < 160
        }

        /// The number of dark pixels in a horizontal band (rows `from..<to`).
        func ink(rows from: Int, _ to: Int) -> Int {
            var count = 0
            for y in max(0, from)..<min(height, to) {
                for x in 0..<width where isDark(x, y) {
                    count += 1
                }
            }
            return count
        }
    }

    private func style(_ size: Int = 24) -> TextStyle {
        TextStyle(family: "Helvetica", size: size)
    }

    private func fontDimension(_ style: TextStyle) -> FontDimension {
        let measurer = CoreTextMeasurer()
        let height = measurer.dimension(of: "|", style: style).height
        return FontDimension(lineHeight: height, baselineOffset: height - measurer.baselineOffset(of: style))
    }

    /// "F" has its bars in the upper half: an upside-down "F" puts the ink below the baseline.
    func testGlyphsAreNotUpsideDown() {
        let bitmap = Bitmap(width: 120, height: 120)
        let context = CGRenderingContext(bitmap.context)
        let textStyle = style(48)
        let dimension = fontDimension(textStyle)
        // The box starts in the upper third of the bitmap.
        let box = Rectangle(x: 10, y: 10, width: 100, height: dimension.lineHeight)
        context.drawText("F", bounds: box, alignment: .left, color: .black,
                         style: textStyle, fontDimension: dimension)

        let boxBottom = box.maxY
        let upper = bitmap.ink(rows: box.y, box.center().y)
        let lower = bitmap.ink(rows: box.center().y, boxBottom)
        XCTAssertGreaterThan(upper, lower,
                             "the ink of an F must be in the upper half of its box: the glyphs are upside down")
    }

    /// The text must stay inside its box and near the top of it.
    func testTextStaysInsideItsBox() {
        let bitmap = Bitmap(width: 200, height: 200)
        let context = CGRenderingContext(bitmap.context)
        let textStyle = style(20)
        let dimension = fontDimension(textStyle)
        let box = Rectangle(x: 10, y: 10, width: 180, height: dimension.lineHeight)
        context.drawText("Hello", bounds: box, alignment: .left, color: .black,
                         style: textStyle, fontDimension: dimension)

        XCTAssertGreaterThan(bitmap.ink(rows: box.y, box.maxY), 20, "the text is drawn inside the box")
        XCTAssertEqual(0, bitmap.ink(rows: box.maxY + 4, 200), "nothing is drawn below the box")
    }

    /// A class node renders its name, attributes and methods in their own compartments.
    func testClassNodeCompartmentsReceiveTheirOwnText() {
        let diagram = Diagram(kind: .class)
        let node = ClassNode()
        node.setName("NAME")
        node.setAttributes("attr")
        node.setMethods("method")
        node.moveTo(Point(x: 10, y: 10))
        diagram.addRootNode(node)

        let renderer = ClassDiagramRenderer(diagram: diagram)
        let box = renderer.bounds(of: node)
        let bitmap = Bitmap(width: box.maxX + 20, height: box.maxY + 20)
        let context = CGRenderingContext(bitmap.context)
        renderer.draw(context)

        // The name compartment is the top ~20 px, attributes and methods follow.
        let nameInk = bitmap.ink(rows: box.y + 2, box.y + 22)
        let middleInk = bitmap.ink(rows: box.y + 22, box.y + 42)
        let bottomInk = bitmap.ink(rows: box.y + 42, box.maxY)
        XCTAssertGreaterThan(nameInk, 20, "the name compartment has text")
        XCTAssertGreaterThan(middleInk, 10, "the attribute compartment has text")
        XCTAssertGreaterThan(bottomInk, 10, "the method compartment has text")

        // The name is bold and centred; check that its ink is horizontally centred.
        var minX = bitmap.width
        var maxX = 0
        for y in (box.y + 2)..<(box.y + 22) {
            for x in 0..<bitmap.width where bitmap.isDark(x, y) {
                minX = min(minX, x)
                maxX = max(maxX, x)
            }
        }
        let inkCenter = (minX + maxX) / 2
        XCTAssertEqual(box.center().x, inkCenter, accuracy: 6, "the name is centred")
    }
}

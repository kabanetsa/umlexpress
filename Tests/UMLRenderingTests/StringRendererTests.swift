import XCTest
@testable import UMLGeometry
@testable import UMLModel
@testable import UMLRendering

/// A measurer with fixed metrics, so that text layout is deterministic in tests.
struct FakeMeasurer: TextMeasurer {
    var characterWidth = 7
    var height = 15
    var ascent = 11

    func dimension(of text: String, style: TextStyle) -> UMLGeometry.Dimension {
        guard !text.isEmpty else { return .null }
        return UMLGeometry.Dimension(width: text.count * characterWidth, height: height)
    }

    func baselineOffset(of style: TextStyle) -> Int {
        ascent
    }
}

/// Records the drawing operations it receives.
final class RecordingContext: RenderingContext {

    enum Call: Equatable {
        case line(x1: Int, y1: Int, x2: Int, y2: Int)
        case text(String, Rectangle, Alignment)
        case rectangle(Rectangle)
        case oval(Int, Int, Int, Int)
    }

    var calls: [Call] = []

    func strokeLine(_ x1: Int, _ y1: Int, _ x2: Int, _ y2: Int, _ color: RGBAColor, _ style: LineStyle) {
        calls.append(.line(x1: x1, y1: y1, x2: x2, y2: y2))
    }

    func drawRectangle(_ rectangle: Rectangle, fill: RGBAColor, stroke: RGBAColor, hasShadow: Bool) {
        calls.append(.rectangle(rectangle))
    }

    func drawOval(_ x: Int, _ y: Int, width: Int, height: Int,
                  fill: RGBAColor, stroke: RGBAColor, hasShadow: Bool) {
        calls.append(.oval(x, y, width, height))
    }

    func strokeArc(centerX: Int, centerY: Int, radius: Int, startAngle: Int, length: Int, color: RGBAColor) {}

    func strokePath(_ path: [PathCommand], color: RGBAColor, style: LineStyle) {}

    func drawClosedPath(_ path: [PathCommand], fill: RGBAColor, stroke: RGBAColor, hasShadow: Bool) {}

    func drawRoundedRectangle(_ rectangle: Rectangle, fill: RGBAColor, stroke: RGBAColor, hasShadow: Bool) {}

    func drawText(_ text: String, bounds: Rectangle, alignment: Alignment, color: RGBAColor,
                  style: TextStyle, fontDimension: FontDimension) {
        calls.append(.text(text, bounds, alignment))
    }
}

/// Port of test/org/jetuml/rendering/StringRendererTest.java
final class StringRendererTests: XCTestCase {

    override func setUp() {
        super.setUp()
        StringRenderer.measurer = FakeMeasurer()
        StringRenderer.baseFont = TextStyle(family: "Test", size: 12)
    }

    override func tearDown() {
        StringRenderer.measurer = CoreTextMeasurer()
        StringRenderer.baseFont = .default
        super.tearDown()
    }

    func testDimension() {
        let renderer = StringRenderer(.left)
        XCTAssertEqual(UMLGeometry.Dimension(width: 21, height: 15), renderer.dimension(of: "abc"))
        XCTAssertEqual(UMLGeometry.Dimension.null, renderer.dimension(of: ""))
    }

    func testLineHeight() {
        let renderer = StringRenderer(.left)
        XCTAssertEqual(15, renderer.lineHeight)
    }

    func testFontDimension() {
        let renderer = StringRenderer(.left)
        // lineHeight - ascent
        XCTAssertEqual(FontDimension(lineHeight: 15, baselineOffset: 4), renderer.fontDimension)
    }

    func testDrawSingleLine() {
        let renderer = StringRenderer(.left)
        let context = RecordingContext()
        renderer.draw("abc", in: Rectangle(x: 10, y: 20, width: 100, height: 15), with: context)
        XCTAssertEqual([.text("abc", Rectangle(x: 10, y: 20, width: 100, height: 15), .left)], context.calls)
    }

    func testDrawMultipleLines() {
        let renderer = StringRenderer(.center)
        let context = RecordingContext()
        renderer.draw("a\nbc", in: Rectangle(x: 0, y: 0, width: 100, height: 30), with: context)
        XCTAssertEqual(2, context.calls.count)
        XCTAssertEqual(.text("a", Rectangle(x: 0, y: 0, width: 100, height: 15), .center), context.calls[0])
        XCTAssertEqual(.text("bc", Rectangle(x: 0, y: 15, width: 100, height: 15), .center), context.calls[1])
    }

    func testBlankLinesAreNotDrawn() {
        let renderer = StringRenderer(.left)
        let context = RecordingContext()
        renderer.draw("a\n   \nb", in: Rectangle(x: 0, y: 0, width: 100, height: 45), with: context)
        XCTAssertEqual(2, context.calls.count)
        XCTAssertEqual("a", context.calls[0].text)
        XCTAssertEqual("b", context.calls[1].text)
    }

    func testUnderline() {
        let renderer = StringRenderer(.left, .underlined)
        let context = RecordingContext()
        renderer.draw("abc", in: Rectangle(x: 10, y: 20, width: 100, height: 15), with: context)
        // text plus one underline stroke, positioned mid-way through the baseline offset
        XCTAssertEqual(2, context.calls.count)
        XCTAssertEqual(.text("abc", Rectangle(x: 10, y: 20, width: 100, height: 15), .left), context.calls[0])
        XCTAssertEqual(.line(x1: 10, y1: 33, x2: 31, y2: 33), context.calls[1])
    }

    func testCenteredUnderlineIsShifted() {
        let renderer = StringRenderer(.center, .underlined)
        let context = RecordingContext()
        renderer.draw("abc", in: Rectangle(x: 0, y: 0, width: 100, height: 15), with: context)
        // x1 = 0 + (100 - 21) / 2 = 39, width 21
        XCTAssertEqual(.line(x1: 39, y1: 13, x2: 60, y2: 13), context.calls[1])
    }

    func testBoldAndItalicDoNotChangeFakeMetrics() {
        let renderer = StringRenderer(.left, .bold, .italic)
        XCTAssertEqual(UMLGeometry.Dimension(width: 14, height: 15), renderer.dimension(of: "ab"))
    }

    func testCoreTextMeasurer() {
        let measurer = CoreTextMeasurer()
        let style = TextStyle(family: "Helvetica", size: 12)
        let short = measurer.dimension(of: "i", style: style)
        let long = measurer.dimension(of: "iiii", style: style)
        XCTAssertGreaterThan(short.width, 0)
        XCTAssertLessThan(short.width, long.width)
        XCTAssertGreaterThan(short.height, 0)
        XCTAssertGreaterThan(measurer.baselineOffset(of: style), 0)

        let larger = measurer.dimension(of: "i", style: TextStyle(family: "Helvetica", size: 24))
        XCTAssertGreaterThan(larger.height, short.height)
    }
}

final class ColorSchemeTests: XCTestCase {

    func testLightScheme() {
        XCTAssertEqual(RGBAColor.white, ColorScheme.light.background)
        XCTAssertEqual(RGBAColor(220, 220, 220), ColorScheme.light.grid)
        XCTAssertEqual(RGBAColor.white, ColorScheme.light.fill)
        XCTAssertEqual(RGBAColor.black, ColorScheme.light.strokeColor)
        XCTAssertEqual(RGBAColor(red: 0.9, green: 0.9, blue: 0.6), ColorScheme.light.noteColor)
        XCTAssertTrue(ColorScheme.light.hasShadows)
    }

    func testDarkScheme() {
        XCTAssertEqual(RGBAColor(7, 7, 7), ColorScheme.dark.background)
        XCTAssertEqual(RGBAColor(40, 40, 40), ColorScheme.dark.grid)
        XCTAssertEqual(RGBAColor(31, 31, 31), ColorScheme.dark.fill)
        XCTAssertEqual(RGBAColor.white, ColorScheme.dark.strokeColor)
        XCTAssertEqual(RGBAColor(30, 63, 102), ColorScheme.dark.noteColor)
        XCTAssertFalse(ColorScheme.dark.hasShadows)
    }

    func testCurrentDefaultsToLight() {
        XCTAssertEqual(ColorScheme.light, ColorScheme.current)
    }
}

private extension RecordingContext.Call {
    var text: String {
        if case let .text(value, _, _) = self {
            return value
        }
        return ""
    }
}

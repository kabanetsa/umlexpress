import XCTest
@testable import UMLGeometry
@testable import UMLModel
@testable import UMLRendering

/// Tests for the SVG rendering context: the emitted markup must match the Java
/// templates byte for byte so that output can be compared with JetUML's own SVG export.
final class SVGRenderingContextTests: XCTestCase {

    private let viewport = Rectangle(x: 0, y: 0, width: 100, height: 50)

    func testDocumentHeaderAndFooter() {
        let context = SVGRenderingContext(viewport: viewport)
        let svg = context.create()
        XCTAssertTrue(svg.hasPrefix("<svg viewBox=\"-7 -7 114 64\" xmlns=\"http://www.w3.org/2000/svg\">"))
        XCTAssertTrue(svg.contains("<g transform=\"translate(0.5,0.5)\" stroke-width=\"0.75\">"))
        XCTAssertTrue(svg.hasSuffix("</g></svg>"))
    }

    func testStrokeLine() {
        let context = SVGRenderingContext(viewport: viewport)
        context.strokeLine(0, 0, 10, 0, .black, .solid)
        XCTAssertEqual("<line x1=\"0\" y1=\"0\" x2=\"10\" y2=\"0\" stroke=\"black\"/>", context.lines.last)
    }

    func testStrokeDottedLine() {
        let context = SVGRenderingContext(viewport: viewport)
        context.strokeLine(0, 0, 10, 0, .black, .dotted)
        XCTAssertEqual("<line x1=\"0\" y1=\"0\" x2=\"10\" y2=\"0\" stroke=\"black\" stroke-dasharray=\"3 3\"/>",
                       context.lines.last)
    }

    func testDrawRectangle() {
        let context = SVGRenderingContext(viewport: viewport)
        context.drawRectangle(Rectangle(x: 5, y: 6, width: 20, height: 10),
                              fill: .white, stroke: .black, hasShadow: false)
        XCTAssertEqual("<rect width=\"20\" height=\"10\" x=\"5\" y=\"6\" stroke=\"black\" fill=\"white\"/>",
                       context.lines.last)
    }

    func testDrawRectangleWithShadow() {
        let context = SVGRenderingContext(viewport: viewport)
        context.drawRectangle(Rectangle(x: 5, y: 6, width: 20, height: 10),
                              fill: .white, stroke: .black, hasShadow: true)
        XCTAssertEqual("<rect width=\"20\" height=\"10\" x=\"7\" y=\"8\" stroke=\"none\" "
            + "fill=\"lightgray\" style=\"filter:url(#shadow);\"/>", context.lines[context.lines.count - 2])
        XCTAssertEqual("<rect width=\"20\" height=\"10\" x=\"5\" y=\"6\" stroke=\"black\" fill=\"white\"/>",
                       context.lines.last)
    }

    func testDrawOval() {
        let context = SVGRenderingContext(viewport: viewport)
        context.drawOval(10, 20, width: 30, height: 40, fill: .white, stroke: .black, hasShadow: false)
        XCTAssertEqual("<ellipse rx=\"15\" ry=\"20\" cx=\"25\" cy=\"40\" stroke=\"black\" fill=\"white\"/>",
                       context.lines.last)
    }

    func testDrawOvalFilledBlack() {
        let context = SVGRenderingContext(viewport: viewport)
        context.drawOval(10, 20, width: 30, height: 40, fill: .black, stroke: .black, hasShadow: false)
        XCTAssertEqual("<ellipse rx=\"15\" ry=\"20\" cx=\"25\" cy=\"40\" stroke=\"black\" fill=\"black\"/>",
                       context.lines.last)
    }

    func testDrawRoundedRectangle() {
        let context = SVGRenderingContext(viewport: viewport)
        context.drawRoundedRectangle(Rectangle(x: 1, y: 2, width: 3, height: 4),
                                     fill: .white, stroke: .black, hasShadow: false)
        XCTAssertEqual("<rect width=\"3\" height=\"4\" x=\"1\" y=\"2\" rx=\"10\" ry=\"10\" "
            + "stroke=\"black\" fill=\"white\"/>", context.lines.last)
    }

    func testStrokePath() {
        let context = SVGRenderingContext(viewport: viewport)
        let path: [PathCommand] = [.move(to: Point(x: 0, y: 0)),
                                   .line(to: Point(x: 10, y: 0)),
                                   .quadCurve(control: Point(x: 20, y: 5), to: Point(x: 30, y: 0))]
        context.strokePath(path, color: .black, style: .solid)
        XCTAssertEqual("<path d=\"M 0 0 L 10 0 Q 20 5 30 0\" stroke=\"black\" fill=\"none\"/>",
                       context.lines.last)
    }

    func testDrawClosedPathNoteColour() {
        let context = SVGRenderingContext(viewport: viewport)
        let path: [PathCommand] = [.move(to: Point(x: 0, y: 0)), .line(to: Point(x: 10, y: 10)),
                                   .line(to: Point(x: 0, y: 10)), .line(to: Point(x: 0, y: 0))]
        context.drawClosedPath(path, fill: ColorScheme.light.noteColor, stroke: .black, hasShadow: false)
        XCTAssertEqual("<path d=\"M 0 0 L 10 10 L 0 10 L 0 0\" stroke=\"black\" fill=\"rgb(90%, 90%, 60%)\"/>",
                       context.lines.last)
    }

    func testDrawTextLeftAndCentered() {
        let context = SVGRenderingContext(viewport: viewport)
        let style = TextStyle(family: "System", size: 12, bold: true)
        let dimension = FontDimension(lineHeight: 15, baselineOffset: 12)

        context.drawText("A<b>", bounds: Rectangle(x: 10, y: 20, width: 100, height: 15),
                         alignment: .left, color: .black, style: style, fontDimension: dimension)
        XCTAssertEqual("<text x=\"10\" y=\"23\" font-size=\"11.75px\" "
            + "font-family=\"Arial, Helvetica, sans-serif\" font-weight=\"bold\" "
            + "font-style=\"normal\" text-anchor=\"start\">A&lt;b&gt;</text>", context.lines.last)

        context.drawText("Hi", bounds: Rectangle(x: 10, y: 20, width: 100, height: 15),
                         alignment: .center, color: .black, style: TextStyle(family: "System", size: 12),
                         fontDimension: dimension)
        XCTAssertEqual("<text x=\"60\" y=\"23\" font-size=\"11.75px\" "
            + "font-family=\"Arial, Helvetica, sans-serif\" font-weight=\"normal\" "
            + "font-style=\"normal\" text-anchor=\"middle\">Hi</text>", context.lines.last)
    }

    func testStrokeArc() {
        let context = SVGRenderingContext(viewport: viewport)
        context.strokeArc(centerX: 50, centerY: 50, radius: 20, startAngle: 0, length: 180, color: .black)
        // Start point is at the bottom middle (sin 0, cos 0), end point mirrored.
        XCTAssertEqual("<path d=\"M 50 70 A 20 20 0 1 1 50 30\" stroke=\"black\" fill=\"none\"/>",
                       context.lines.last)
    }
}

import CoreGraphics
import XCTest
@testable import UMLGeometry
@testable import UMLInteraction
@testable import UMLModel
@testable import UMLRendering


/// Multi-line text metrics: the node boxes must grow with their content, otherwise the text
/// spills into the neighbouring compartments and everything around it shifts.
final class MultiLineMetricsTests: XCTestCase {

    private let measurer = CoreTextMeasurer()
    private let style = TextStyle(family: "Helvetica", size: 12)

    func testMultiLineHeightIsPerLineAndNotSummedWidth() {
        let single = measurer.dimension(of: "abc", style: style)
        let double = measurer.dimension(of: "abc\ndef", style: style)
        let triple = measurer.dimension(of: "abc\ndef\nghi", style: style)

        XCTAssertGreaterThan(single.height, 0)
        XCTAssertEqual(single.height * 2, double.height, "two lines are twice as tall")
        XCTAssertEqual(single.height * 3, triple.height, "three lines are three times as tall")
        // The width is the widest line, not the sum of the lines.
        XCTAssertEqual(single.width, double.width)
        XCTAssertEqual(single.width, triple.width)
    }

    func testWidestLineDeterminesTheWidth() {
        let dimension = measurer.dimension(of: "a\nlonger line\nb", style: style)
        let longest = measurer.dimension(of: "longer line", style: style)
        XCTAssertEqual(longest.width, dimension.width)
    }

    /// A class node with attributes and methods is measured with one line per entry.
    func testClassNodeBoundsGrowPerAttributeLine() {
        let empty = ClassNode()
        empty.setName("A")
        let withOne = ClassNode()
        withOne.setName("A")
        withOne.setAttributes("+attr")
        let withThree = ClassNode()
        withThree.setName("A")
        withThree.setAttributes("+a1\n+a2\n+a3")

        let renderer1 = ClassDiagramRenderer(diagram: diagramWith(empty))
        let renderer2 = ClassDiagramRenderer(diagram: diagramWith(withOne))
        let renderer3 = ClassDiagramRenderer(diagram: diagramWith(withThree))

        let baseHeight = renderer1.bounds(of: empty).height
        let oneHeight = renderer2.bounds(of: withOne).height
        let threeHeight = renderer3.bounds(of: withThree).height

        // A class box has a minimum height (60 px in the original): one attribute line is
        // absorbed by shrinking the name compartment, three lines force the box to grow.
        XCTAssertEqual(baseHeight, oneHeight, "one attribute line fits in the default height")
        XCTAssertGreaterThan(threeHeight, oneHeight, "three attribute lines make the box taller")
        let lineHeight = StringRenderer(.left).lineHeight
        XCTAssertGreaterThanOrEqual(threeHeight, oneHeight + 2 * lineHeight - lineHeight,
                                    "the growth is on the order of the extra lines")
    }

    private func diagramWith(_ node: any Node) -> Diagram {
        let diagram = Diagram(kind: .class)
        node.moveTo(Point(x: 0, y: 0))
        diagram.addRootNode(node)
        return diagram
    }

    /// The three compartments keep their own text after the box grows (the reported symptom).
    func testCompartmentsStayAlignedAfterEditing() {
        let diagram = Diagram(kind: .class)
        let node = ClassNode()
        node.setName("NAME")
        node.moveTo(Point(x: 10, y: 10))
        diagram.addRootNode(node)

        // Edit the node the way the property sheet does, adding several lines.
        let sheet = PropertySheetModel(element: node)
        sheet.setRawValue("+a1\n+a2\n+a3", for: .attributes)
        sheet.setRawValue("+m1\n+m2", for: .methods)

        let renderer = ClassDiagramRenderer(diagram: diagram)
        let box = renderer.bounds(of: node)
        let bitmap = CGTextRenderingTestsBitmap(width: box.maxX + 20, height: box.maxY + 40)
        let context = CGRenderingContext(bitmap.context)
        renderer.draw(context)

        let lineHeight = StringRenderer(.left).lineHeight
        // The last method must stay inside the box.
        let inkBelowBox = bitmap.ink(rows: box.maxY + 2, bitmap.height)
        XCTAssertEqual(0, inkBelowBox, "no text may spill below the node box")
        // The name compartment, the attribute area and the method area all contain ink.
        XCTAssertGreaterThan(bitmap.ink(rows: box.y + 2, box.y + lineHeight), 10)
        XCTAssertGreaterThan(bitmap.ink(rows: box.y + lineHeight, box.y + 4 * lineHeight), 10)
        XCTAssertGreaterThan(bitmap.ink(rows: box.maxY - 3 * lineHeight, box.maxY - 2), 10)
    }
}

/// The bitmap helper used by the tests above (mirrors the one in `CGTextRenderingTests`).
private final class CGTextRenderingTestsBitmap {
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
        return Int(data[offset]) < 160 && Int(data[offset + 1]) < 160 && Int(data[offset + 2]) < 160
    }

    func ink(rows from: Int, _ to: Int) -> Int {
        var count = 0
        for y in max(0, from)..<min(height, to) where y >= 0 {
            for x in 0..<width where isDark(x, y) {
                count += 1
            }
        }
        return count
    }
}

/// The label of a package node sits in the middle of its tab.
///
/// The original draws the label from the top edge of the tab, which leaves the name
/// hugging the top border; the tab is 20 points high and the text block is centred here.
final class PackageLabelPlacementTests: XCTestCase {

    private func render(_ diagram: Diagram) -> CGTextRenderingTestsBitmap {
        let bitmap = CGTextRenderingTestsBitmap(width: 400, height: 300)
        let renderer = DiagramRendererFactory.renderer(for: diagram)
        renderer.drawDiagram(CGRenderingContext(bitmap.context))
        return bitmap
    }

    func testLabelIsCentredInTheTab() throws {
        let diagram = Diagram(kind: .class)
        let node = PackageNode()
        node.setName("package")
        node.moveTo(Point(x: 40, y: 40))
        diagram.addRootNode(node)

        let concrete = try XCTUnwrap(DiagramRendererFactory.renderer(for: diagram)
            as? AbstractDiagramRenderer)
        let nodeRenderer = try XCTUnwrap(concrete.nodeRenderer(for: node)
            as? AbstractPackageNodeRenderer)
        let tab = nodeRenderer.topBounds(node)
        let bitmap = render(diagram)

        // Rows of the label inside the tab, ignoring the border of the tab itself.
        var firstInk = -1
        var lastInk = -1
        for y in (tab.y + 2)..<(tab.maxY - 1) {
            var hasInk = false
            // Skip the vertical borders of the tab.
            for x in (tab.x + 2)..<(tab.maxX - 2) where bitmap.isDark(x, y) {
                hasInk = true
                break
            }
            if hasInk {
                if firstInk < 0 { firstInk = y }
                lastInk = y
            }
        }
        XCTAssertGreaterThan(firstInk, 0, "the tab must show the name")
        let gapAbove = firstInk - (tab.y + 1)
        let gapBelow = (tab.maxY - 1) - lastInk
        XCTAssertLessThanOrEqual(abs(gapAbove - gapBelow), 2,
                                 "the name must be centred in the tab "
                                 + "(above: \(gapAbove), below: \(gapBelow))")
        XCTAssertGreaterThanOrEqual(gapAbove, 1, "the name must not touch the top border")
    }
}

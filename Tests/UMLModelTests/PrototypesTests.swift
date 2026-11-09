import XCTest
@testable import UMLModel

/// Tests for `Prototypes` and the per-diagram-type palette contents.
final class PrototypesTests: XCTestCase {

    func testSingleton() {
        XCTAssertTrue(Prototypes.shared === Prototypes.shared)
    }

    func testPrototypesAreDistinctInstances() {
        let prototypes = Prototypes.shared
        XCTAssertFalse(prototypes.classNode === prototypes.interfaceNode)
        XCTAssertFalse(prototypes.aggregation === prototypes.composition)
        XCTAssertEqual(.aggregation, (prototypes.aggregation as? AggregationEdge)?.type)
        XCTAssertEqual(.composition, (prototypes.composition as? AggregationEdge)?.type)
        XCTAssertEqual(.implementation, (prototypes.realization as? GeneralizationEdge)?.type)
        XCTAssertEqual(.include, (prototypes.useCaseIncludes as? UseCaseDependencyEdge)?.type)
        XCTAssertEqual(.extend, (prototypes.useCaseExtends as? UseCaseDependencyEdge)?.type)
    }

    /// Palette sizes and order, as in `DiagramType`.
    func testPaletteContents() {
        let prototypes = Prototypes.shared
        let expected: [ObjectIdentifier] = [
            prototypes.classNode, prototypes.interfaceNode, prototypes.package,
            prototypes.packageDescription, prototypes.note, prototypes.dependency,
            prototypes.generalization, prototypes.realization, prototypes.association,
            prototypes.aggregation, prototypes.composition, prototypes.noteConnector,
        ].map(ObjectIdentifier.init)
        XCTAssertEqual(expected, DiagramKind.class.prototypes.map(ObjectIdentifier.init))

        XCTAssertEqual(5, DiagramKind.sequence.prototypes.count)
        XCTAssertEqual(6, DiagramKind.state.prototypes.count)
        XCTAssertEqual(6, DiagramKind.object.prototypes.count)
        XCTAssertEqual(8, DiagramKind.useCase.prototypes.count)

        // Every palette starts with the note connector sentinel at the end.
        for kind in DiagramKind.allCases {
            XCTAssertTrue(kind.prototypes.last === prototypes.noteConnector, "\(kind)")
        }
    }

    func testTooltips() {
        let prototypes = Prototypes.shared
        XCTAssertEqual("class.tooltip", prototypes.tooltip(prototypes.classNode, verbose: false))
        XCTAssertEqual("class.tooltip | class.tooltip.verbose",
                       prototypes.tooltip(prototypes.classNode, verbose: true))
        XCTAssertEqual("[tooltip not found]", prototypes.tooltip(ClassNode(), verbose: false))
    }
}

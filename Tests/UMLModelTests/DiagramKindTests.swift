import XCTest
@testable import UMLModel

/// Port of test/org/jetuml/diagram/DiagramTypeTest.java (data-only part) and
/// test/org/jetuml/diagram/PropertyNameTest.java.
final class DiagramKindTests: XCTestCase {

    func testFromName() throws {
        XCTAssertEqual(.class, try DiagramKind.fromName("ClassDiagram"))
        XCTAssertEqual(.sequence, try DiagramKind.fromName("SequenceDiagram"))
        XCTAssertEqual(.state, try DiagramKind.fromName("StateDiagram"))
        XCTAssertEqual(.object, try DiagramKind.fromName("ObjectDiagram"))
        XCTAssertEqual(.useCase, try DiagramKind.fromName("UseCaseDiagram"))
    }

    func testFromNameInvalid() {
        XCTAssertThrowsError(try DiagramKind.fromName("NopeDiagram")) { error in
            XCTAssertEqual(DiagramKindError.invalidName("NopeDiagram"), error as? DiagramKindError)
        }
    }

    func testNames() {
        XCTAssertEqual("ClassDiagram", DiagramKind.class.name)
        XCTAssertEqual("SequenceDiagram", DiagramKind.sequence.name)
        XCTAssertEqual("StateDiagram", DiagramKind.state.name)
        XCTAssertEqual("ObjectDiagram", DiagramKind.object.name)
        XCTAssertEqual("UseCaseDiagram", DiagramKind.useCase.name)
    }

    func testAllCases() {
        XCTAssertEqual(5, DiagramKind.allCases.count)
    }
}

final class PropertyNameTests: XCTestCase {

    /// The external representation must stay byte-identical with the Java format.
    func testExternalRepresentation() {
        XCTAssertEqual("Aggregation Type", PropertyName.aggregationType.external)
        XCTAssertEqual("attributes", PropertyName.attributes.external)
        XCTAssertEqual("contents", PropertyName.contents.external)
        XCTAssertEqual("directionality", PropertyName.directionality.external)
        XCTAssertEqual("endLabel", PropertyName.endLabel.external)
        XCTAssertEqual("Generalization Type", PropertyName.generalizationType.external)
        XCTAssertEqual("methods", PropertyName.methods.external)
        XCTAssertEqual("middleLabel", PropertyName.middleLabel.external)
        XCTAssertEqual("name", PropertyName.name.external)
        XCTAssertEqual("openBottom", PropertyName.openBottom.external)
        XCTAssertEqual("signal", PropertyName.signal.external)
        XCTAssertEqual("startLabel", PropertyName.startLabel.external)
        XCTAssertEqual("Dependency Type", PropertyName.useCaseDependencyType.external)
        XCTAssertEqual("value", PropertyName.value.external)
    }

    func testAllCases() {
        XCTAssertEqual(14, PropertyName.allCases.count)
    }
}

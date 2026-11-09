import XCTest
@testable import UMLModel

/// Tests for the concrete edge types (port of the property expectations in
/// test/org/jetuml/diagram/edges/*Test.java).
final class EdgeTypesTests: XCTestCase {

    func testAggregationEdge() {
        let edge = AggregationEdge()
        XCTAssertEqual(.aggregation, edge.type)
        XCTAssertEqual("Aggregation", edge.properties.string(.aggregationType))
        XCTAssertEqual([.startLabel, .middleLabel, .endLabel, .aggregationType],
                       edge.properties.map(\.name))

        edge.setType(.composition)
        XCTAssertEqual("Composition", edge.properties.string(.aggregationType))

        // The property setter accepts the external representation, as in Java.
        edge.properties.get(.aggregationType).set("Aggregation")
        XCTAssertEqual(.aggregation, edge.type)
    }

    func testAggregationEdgeWithType() {
        let edge = AggregationEdge(.composition)
        XCTAssertEqual(.composition, edge.type)
    }

    func testAssociationEdge() {
        let edge = AssociationEdge()
        XCTAssertEqual(.unspecified, edge.directionality)
        XCTAssertEqual("Unspecified", edge.properties.string(.directionality))
        edge.setDirectionality(.bidirectional)
        XCTAssertEqual("Bidirectional", edge.properties.string(.directionality))
    }

    func testDependencyEdge() {
        let edge = DependencyEdge()
        XCTAssertEqual(.unidirectional, edge.directionality)
        XCTAssertEqual("Unidirectional", edge.properties.string(.directionality))
        XCTAssertEqual([.middleLabel, .directionality], edge.properties.map(\.name))
        edge.setDirectionality(.bidirectional)
        XCTAssertEqual(.bidirectional, edge.directionality)
    }

    func testGeneralizationEdge() {
        XCTAssertEqual(.inheritance, GeneralizationEdge().type)
        XCTAssertEqual(.implementation, GeneralizationEdge(.implementation).type)
        let edge = GeneralizationEdge(.implementation)
        XCTAssertEqual("Implementation", edge.properties.string(.generalizationType))
        XCTAssertEqual([.generalizationType], edge.properties.map(\.name))
    }

    func testCallEdgeSignal() {
        let edge = CallEdge()
        XCTAssertFalse(edge.isSignal)
        edge.setSignal(true)
        XCTAssertTrue(edge.properties.bool(.signal))
        XCTAssertEqual([.middleLabel, .signal], edge.properties.map(\.name))
    }

    func testCallEdgeSelfEdge() {
        let parameter = ImplicitParameterNode()
        let call1 = CallNode()
        let call2 = CallNode()
        parameter.addChild(call1)
        parameter.addChild(call2)

        let selfEdge = CallEdge()
        selfEdge.connect(call1, call2)
        XCTAssertTrue(selfEdge.isSelfEdge)

        let otherParameter = ImplicitParameterNode()
        let call3 = CallNode()
        otherParameter.addChild(call3)
        let crossEdge = CallEdge()
        crossEdge.connect(call1, call3)
        XCTAssertFalse(crossEdge.isSelfEdge)
    }

    func testConstructorEdge() {
        let edge = ConstructorEdge()
        XCTAssertEqual("\u{00AB}create\u{00BB}", edge.middleLabel)
        XCTAssertTrue(edge.isSignal == false)
    }

    func testUseCaseDependencyEdge() {
        XCTAssertEqual(.none, UseCaseDependencyEdge().type)
        XCTAssertEqual("", UseCaseDependencyEdge.UseCaseDependencyType.none.label)
        XCTAssertEqual("\u{00AB}include\u{00BB}", UseCaseDependencyEdge.UseCaseDependencyType.include.label)
        XCTAssertEqual("\u{00AB}extend\u{00BB}", UseCaseDependencyEdge.UseCaseDependencyType.extend.label)

        let edge = UseCaseDependencyEdge(.include)
        XCTAssertEqual("Include", edge.properties.string(.useCaseDependencyType))
        XCTAssertEqual([.useCaseDependencyType], edge.properties.map(\.name))
    }

    func testSimpleEdgePropertySets() {
        XCTAssertEqual([.middleLabel], ReturnEdge().properties.map(\.name))
        XCTAssertEqual([.middleLabel], ObjectCollaborationEdge().properties.map(\.name))
        XCTAssertEqual([.middleLabel], StateTransitionEdge().properties.map(\.name))
        XCTAssertEqual([], NoteEdge().properties.map(\.name))
        XCTAssertEqual([], ObjectReferenceEdge().properties.map(\.name))
        XCTAssertEqual([], UseCaseAssociationEdge().properties.map(\.name))
        XCTAssertEqual([], UseCaseGeneralizationEdge().properties.map(\.name))
    }

    func testCopiesPreserveType() {
        let aggregation = AggregationEdge(.composition)
        XCTAssertEqual(.composition, aggregation.copy().type)

        let association = AssociationEdge()
        association.setDirectionality(.unidirectional)
        XCTAssertEqual(.unidirectional, association.copy().directionality)

        let generalization = GeneralizationEdge(.implementation)
        XCTAssertEqual(.implementation, generalization.copy().type)

        let dependency = UseCaseDependencyEdge(.extend)
        XCTAssertEqual(.extend, dependency.copy().type)

        let call = CallEdge()
        call.setSignal(true)
        XCTAssertTrue(call.copy().isSignal)
    }
}

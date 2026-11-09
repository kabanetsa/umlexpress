import XCTest
@testable import UMLModel
@testable import UMLValidation

/// Validators for the state, object and use case diagrams (M8).
final class OtherValidatorsTests: XCTestCase {

    // MARK: - State diagrams

    func testEmptyStateDiagramIsValid() {
        XCTAssertTrue(StateDiagramValidator(Diagram(kind: .state)).isValid)
    }

    func testInitialToStateTransitionIsValid() {
        let diagram = Diagram(kind: .state)
        let initial = InitialStateNode()
        let state = StateNode()
        diagram.addRootNode(initial)
        diagram.addRootNode(state)
        let edge = StateTransitionEdge()
        edge.connect(initial, state)
        diagram.addEdge(edge)
        XCTAssertNil(StateDiagramValidator(diagram).validate())
    }

    func testTransitionCannotStartInFinalState() {
        let diagram = Diagram(kind: .state)
        let final = FinalStateNode()
        let state = StateNode()
        diagram.addRootNode(final)
        diagram.addRootNode(state)
        let edge = StateTransitionEdge()
        edge.connect(final, state)
        diagram.addEdge(edge)
        XCTAssertEqual(.semantic(ConstraintValidTransitionEdgeStartNode()),
                       StateDiagramValidator(diagram).validate())
    }

    func testTransitionCannotEndInInitialState() {
        let diagram = Diagram(kind: .state)
        let initial = InitialStateNode()
        let state = StateNode()
        diagram.addRootNode(initial)
        diagram.addRootNode(state)
        let edge = StateTransitionEdge()
        edge.connect(state, initial)
        diagram.addEdge(edge)
        XCTAssertEqual(.semantic(ConstraintValidTransitionEdgeEndNode()),
                       StateDiagramValidator(diagram).validate())
    }

    func testClassNodeIsInvalidInStateDiagram() {
        let diagram = Diagram(kind: .state)
        diagram.addRootNode(ClassNode())
        XCTAssertEqual(.structural("StructureInvalidElements"), StateDiagramValidator(diagram).validate())
    }

    // MARK: - Object diagrams

    private func makeObjectDiagram() -> (Diagram, ObjectNode, FieldNode) {
        let diagram = Diagram(kind: .object)
        let object = ObjectNode()
        object.setName(":A")
        let field = FieldNode()
        field.setName("f")
        object.addChild(field)
        diagram.addRootNode(object)
        return (diagram, object, field)
    }

    func testObjectDiagramWithFieldIsValid() {
        let (diagram, _, _) = makeObjectDiagram()
        XCTAssertNil(ObjectDiagramValidator(diagram).validate())
    }

    func testFieldAsRootNodeIsInvalid() {
        let diagram = Diagram(kind: .object)
        diagram.addRootNode(FieldNode())
        XCTAssertEqual(.structural("StructureInvalidNodes"), ObjectDiagramValidator(diagram).validate())
    }

    func testReferenceEdgeMustGoFromFieldToObject() {
        let (diagram, object, field) = makeObjectDiagram()
        let reversed = ObjectReferenceEdge()
        reversed.connect(object, field)
        diagram.addEdge(reversed)
        XCTAssertEqual(.semantic(ConstraintValidReferenceEdge()),
                       ObjectDiagramValidator(diagram).validate())
    }

    func testCollaborationEdgeBetweenObjectsIsValid() {
        let (diagram, object, _) = makeObjectDiagram()
        let other = ObjectNode()
        other.setName(":B")
        diagram.addRootNode(other)
        let edge = ObjectCollaborationEdge()
        edge.connect(object, other)
        diagram.addEdge(edge)
        XCTAssertNil(ObjectDiagramValidator(diagram).validate())
    }

    func testCollaborationEdgeToFieldIsInvalid() {
        let (diagram, object, field) = makeObjectDiagram()
        let edge = ObjectCollaborationEdge()
        edge.connect(object, field)
        diagram.addEdge(edge)
        XCTAssertEqual(.semantic(ConstraintValidCollaborationEdge()),
                       ObjectDiagramValidator(diagram).validate())
    }

    // MARK: - Use case diagrams

    func testUseCaseDiagramIsValid() {
        let diagram = Diagram(kind: .useCase)
        let actor = ActorNode()
        let useCase = UseCaseNode()
        useCase.setName("Buy")
        diagram.addRootNode(actor)
        diagram.addRootNode(useCase)
        let edge = UseCaseAssociationEdge()
        edge.connect(actor, useCase)
        diagram.addEdge(edge)
        XCTAssertNil(UseCaseDiagramValidator(diagram).validate())
    }

    func testSelfAssociationIsInvalid() {
        let diagram = Diagram(kind: .useCase)
        let useCase = UseCaseNode()
        diagram.addRootNode(useCase)
        let edge = UseCaseAssociationEdge()
        edge.connect(useCase, useCase)
        diagram.addEdge(edge)
        XCTAssertEqual(.semantic(ConstraintNoSelfEdgeForEdgeType(UseCaseAssociationEdge.self)),
                       UseCaseDiagramValidator(diagram).validate())
    }

    func testStateNodeIsInvalidInUseCaseDiagram() {
        let diagram = Diagram(kind: .useCase)
        diagram.addRootNode(StateNode())
        XCTAssertEqual(.structural("StructureInvalidElements"), UseCaseDiagramValidator(diagram).validate())
    }

    // MARK: - Factory and persistence integration

    func testFactoryReturnsValidatorPerKind() {
        XCTAssertTrue(DiagramValidatorFactory.validator(for: Diagram(kind: .class)) is ClassDiagramValidator)
        XCTAssertTrue(DiagramValidatorFactory.validator(for: Diagram(kind: .state)) is StateDiagramValidator)
        XCTAssertTrue(DiagramValidatorFactory.validator(for: Diagram(kind: .object)) is ObjectDiagramValidator)
        XCTAssertTrue(DiagramValidatorFactory.validator(for: Diagram(kind: .useCase)) is UseCaseDiagramValidator)
        XCTAssertTrue(DiagramValidatorFactory.validator(for: Diagram(kind: .sequence)) is SequenceDiagramValidator)
    }
}

/// Validator for sequence diagrams.
final class SequenceValidatorTests: XCTestCase {

    func testEmptySequenceDiagramIsValid() {
        XCTAssertTrue(SequenceDiagramValidator(Diagram(kind: .sequence)).isValid)
    }

    func testCallBetweenCallNodesIsValid() {
        let diagram = Diagram(kind: .sequence)
        let client = ImplicitParameterNode()
        let server = ImplicitParameterNode()
        diagram.addRootNode(client)
        diagram.addRootNode(server)
        let root = CallNode()
        client.addChild(root)
        let target = CallNode()
        server.addChild(target)
        let edge = CallEdge()
        edge.connect(root, target)
        diagram.addEdge(edge)
        XCTAssertNil(SequenceDiagramValidator(diagram).validate())
    }

    func testCallEdgeFromImplicitParameterIsInvalid() {
        let diagram = Diagram(kind: .sequence)
        let client = ImplicitParameterNode()
        let server = ImplicitParameterNode()
        diagram.addRootNode(client)
        diagram.addRootNode(server)
        let target = CallNode()
        server.addChild(target)
        let edge = CallEdge()
        edge.connect(client, target)
        diagram.addEdge(edge)
        XCTAssertEqual(.semantic(ConstraintCallEdgeBetweenCallNodes()),
                       SequenceDiagramValidator(diagram).validate())
    }

    func testCallNodeAsRootIsInvalid() {
        let diagram = Diagram(kind: .sequence)
        diagram.addRootNode(CallNode())
        XCTAssertEqual(.structural("StructureInvalidNodes"), SequenceDiagramValidator(diagram).validate())
    }

    func testReturnMustGoToTheCaller() {
        let diagram = Diagram(kind: .sequence)
        let client = ImplicitParameterNode()
        let server = ImplicitParameterNode()
        diagram.addRootNode(client)
        diagram.addRootNode(server)
        let root = CallNode()
        client.addChild(root)
        let target = CallNode()
        server.addChild(target)
        let call = CallEdge()
        call.connect(root, target)
        diagram.addEdge(call)

        let validReturn = ReturnEdge()
        validReturn.connect(target, root)
        diagram.addEdge(validReturn)
        XCTAssertNil(SequenceDiagramValidator(diagram).validate())

        // A return to a node that is not the caller is invalid.
        let other = CallNode()
        server.addChild(other)
        let secondCall = CallEdge()
        secondCall.connect(root, other)
        diagram.addEdge(secondCall)
        let invalidReturn = ReturnEdge()
        invalidReturn.connect(target, other)
        diagram.addEdge(invalidReturn)
        XCTAssertEqual(.semantic(ConstraintReturnsToCaller()),
                       SequenceDiagramValidator(diagram).validate())
    }

    func testTwoCallersAreInvalid() {
        let diagram = Diagram(kind: .sequence)
        let client = ImplicitParameterNode()
        let serverA = ImplicitParameterNode()
        let serverB = ImplicitParameterNode()
        let target2 = ImplicitParameterNode()
        diagram.addRootNode(client)
        diagram.addRootNode(serverA)
        diagram.addRootNode(serverB)
        diagram.addRootNode(target2)

        let root = CallNode()
        client.addChild(root)
        let first = CallNode()
        serverA.addChild(first)
        let second = CallNode()
        serverB.addChild(second)
        let target = CallNode()
        target2.addChild(target)

        let rootToFirst = CallEdge()
        rootToFirst.connect(root, first)
        diagram.addEdge(rootToFirst)
        let rootToSecond = CallEdge()
        rootToSecond.connect(root, second)
        diagram.addEdge(rootToSecond)
        let firstToTarget = CallEdge()
        firstToTarget.connect(first, target)
        diagram.addEdge(firstToTarget)
        let secondToTarget = CallEdge()
        secondToTarget.connect(second, target)
        diagram.addEdge(secondToTarget)

        XCTAssertEqual(.semantic(ConstraintMaxOneCaller()), SequenceDiagramValidator(diagram).validate())
    }
}

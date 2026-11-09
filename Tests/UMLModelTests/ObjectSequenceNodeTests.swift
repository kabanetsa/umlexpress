import XCTest
@testable import UMLGeometry
@testable import UMLModel

/// Port of test/org/jetuml/diagram/nodes/ObjectNodeTest.java and
/// FieldNodeTest.java.
final class ObjectNodeTests: XCTestCase {

    func testDefaults() {
        let node = ObjectNode()
        XCTAssertEqual("", node.name)
        XCTAssertTrue(node.children.isEmpty)
        XCTAssertFalse(node.hasParent)
    }

    func testAddField() {
        let node = ObjectNode()
        let field = FieldNode()
        node.addChild(field)
        XCTAssertEqual(1, node.children.count)
        XCTAssertTrue(field.hasParent)
        XCTAssertTrue(field.getParent() === node)
    }

    func testAllowsAsChild() {
        let node = ObjectNode()
        XCTAssertTrue(node.allowsAsChild(FieldNode()))
        XCTAssertFalse(node.allowsAsChild(ClassNode()))
    }

    func testRemoveFieldUnlinks() {
        let node = ObjectNode()
        let field = FieldNode()
        node.addChild(field)
        node.removeChild(field)
        XCTAssertTrue(node.children.isEmpty)
        XCTAssertFalse(field.hasParent)
    }

    func testTranslatePropagatesToFields() {
        let node = ObjectNode()
        let field = FieldNode()
        node.addChild(field)
        node.translate(2, 3)
        XCTAssertEqual(Point(x: 2, y: 3), field.position)
    }

    func testCopyIsDeepAndRelinked() {
        let node = ObjectNode()
        let field = FieldNode()
        field.setName("id")
        field.setValue("42")
        node.addChild(field)
        node.setName("obj")

        let copy = node.copy()
        XCTAssertEqual("obj", copy.name)
        XCTAssertEqual(1, copy.children.count)
        XCTAssertFalse(copy.children[0] === field)
        XCTAssertTrue(copy.children[0].getParent() === copy)
        XCTAssertEqual("id", (copy.children[0] as? FieldNode)?.name)
        XCTAssertEqual("42", (copy.children[0] as? FieldNode)?.value)
    }
}

final class FieldNodeTests: XCTestCase {

    func testDefaults() {
        let field = FieldNode()
        XCTAssertEqual("name", field.name)
        XCTAssertEqual("value", field.value)
        XCTAssertTrue(field.requiresParent)
        XCTAssertFalse(field.hasParent)
        XCTAssertEqual([.name, .value], field.properties.map(\.name))
    }

    func testValueBinding() {
        let field = FieldNode()
        field.properties.get(.value).set("7")
        XCTAssertEqual("7", field.value)
        XCTAssertEqual("7", field.properties.string(.value))
    }
}

/// Port of test/org/jetuml/diagram/nodes/ActorNodeTest.java and the trivial nodes.
final class SimpleNodeTests: XCTestCase {

    func testActorDefaultName() {
        let actor = ActorNode()
        XCTAssertEqual("Actor", actor.name)
        XCTAssertEqual([.name], actor.properties.map(\.name))
    }

    func testUseCaseNode() {
        let node = UseCaseNode()
        XCTAssertEqual("", node.name)
        node.setName("Buy")
        XCTAssertEqual("Buy", node.name)
    }

    func testStateNode() {
        let node = StateNode()
        XCTAssertEqual("", node.name)
        XCTAssertEqual([.name], node.properties.map(\.name))
    }

    func testStateMarkers() {
        XCTAssertEqual([], InitialStateNode().properties.map(\.name))
        XCTAssertEqual([], FinalStateNode().properties.map(\.name))
        XCTAssertEqual([], PointNode().properties.map(\.name))
    }

    func testStateMarkerCopyIsIndependent() {
        let node = InitialStateNode()
        node.moveTo(Point(x: 5, y: 6))
        let copy = node.copy()
        XCTAssertFalse(copy === node)
        XCTAssertEqual(Point(x: 5, y: 6), copy.position)
    }
}

/// Port of test/org/jetuml/diagram/nodes/ImplicitParameterNodeTest.java and
/// CallNodeTest.java.
final class SequenceNodeTests: XCTestCase {

    func testImplicitParameterChildren() {
        let parameter = ImplicitParameterNode()
        let call = CallNode()
        parameter.addChild(call)
        XCTAssertEqual(1, parameter.children.count)
        XCTAssertTrue(call.hasParent)
        XCTAssertTrue(call.getParent() === parameter)
        XCTAssertTrue(parameter.allowsAsChild(CallNode()))
        XCTAssertFalse(parameter.allowsAsChild(ClassNode()))
    }

    func testImplicitParameterDescription() {
        let parameter = ImplicitParameterNode()
        parameter.setName(":Client")
        XCTAssertEqual("[ImplicitParameterNode: :Client]", parameter.description)
    }

    func testImplicitParameterCopyIsDeep() {
        let parameter = ImplicitParameterNode()
        let call = CallNode()
        parameter.addChild(call)
        parameter.setName("p")

        let copy = parameter.copy()
        XCTAssertEqual("p", copy.name)
        XCTAssertEqual(1, copy.children.count)
        XCTAssertFalse(copy.children[0] === call)
        XCTAssertTrue(copy.children[0].getParent() === copy)
    }

    func testCallNodeDefaults() {
        let call = CallNode()
        XCTAssertTrue(call.requiresParent)
        XCTAssertFalse(call.hasParent)
        XCTAssertFalse(call.isOpenBottom)
        XCTAssertEqual([.openBottom], call.properties.map(\.name))
        XCTAssertEqual(20, CallNode.callYGap)
    }

    func testCallNodeOpenBottomBinding() {
        let call = CallNode()
        call.setOpenBottom(true)
        XCTAssertTrue(call.properties.bool(.openBottom))
        call.properties.get(.openBottom).set(false)
        XCTAssertFalse(call.isOpenBottom)
    }

    func testCallNodeDescriptionUsesIndex() {
        let parameter = ImplicitParameterNode()
        parameter.setName("p")
        let first = CallNode()
        let second = CallNode()
        parameter.addChild(first)
        parameter.addChild(second)
        XCTAssertEqual("[Call node #1 of [ImplicitParameterNode: p]]", first.description)
        XCTAssertEqual("[Call node #2 of [ImplicitParameterNode: p]]", second.description)
    }
}

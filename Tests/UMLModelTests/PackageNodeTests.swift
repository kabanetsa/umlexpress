import XCTest
@testable import UMLGeometry
@testable import UMLModel

/// Port of test/org/jetuml/diagram/nodes/PackageNodeTest.java and
/// PackageDescriptionNodeTest.java.
final class PackageNodeTests: XCTestCase {

    func testDefaults() {
        let package = PackageNode()
        XCTAssertEqual("", package.name)
        XCTAssertTrue(package.children.isEmpty)
        XCTAssertFalse(package.hasParent)
        XCTAssertFalse(package.requiresParent)
    }

    func testAddChildLinks() {
        let package = PackageNode()
        let child = ClassNode()
        package.addChild(child)
        XCTAssertEqual(1, package.children.count)
        XCTAssertTrue(package.children[0] === child)
        XCTAssertTrue(child.hasParent)
        XCTAssertTrue(child.getParent() === package)
    }

    func testAddChildAt() {
        let package = PackageNode()
        let first = ClassNode()
        let second = InterfaceNode()
        package.addChild(first)
        package.addChild(second, at: 0)
        XCTAssertTrue(package.children[0] === second)
        XCTAssertTrue(package.children[1] === first)
    }

    func testAddChildMovesFromOtherParent() {
        let package1 = PackageNode()
        let package2 = PackageNode()
        let child = ClassNode()
        package1.addChild(child)
        package2.addChild(child)
        XCTAssertEqual(1, package2.children.count)
        XCTAssertTrue(package1.children.isEmpty)
        XCTAssertTrue(child.getParent() === package2)
    }

    func testAllowsAsChild() {
        let package = PackageNode()
        XCTAssertTrue(package.allowsAsChild(ClassNode()))
        XCTAssertTrue(package.allowsAsChild(InterfaceNode()))
        XCTAssertTrue(package.allowsAsChild(PackageNode()))
        XCTAssertFalse(package.allowsAsChild(NoteNode()))
        XCTAssertFalse(package.allowsAsChild(StateNode()))
    }

    func testRemoveChildUnlinks() {
        let package = PackageNode()
        let child = ClassNode()
        package.addChild(child)
        package.removeChild(child)
        XCTAssertTrue(package.children.isEmpty)
        XCTAssertFalse(child.hasParent)
    }

    func testTranslatePropagatesToChildren() {
        let package = PackageNode()
        let child = ClassNode()
        package.addChild(child)
        child.moveTo(Point(x: 10, y: 10))
        package.moveTo(Point(x: 100, y: 100))
        package.translate(5, 5)
        XCTAssertEqual(Point(x: 105, y: 105), package.position)
        XCTAssertEqual(Point(x: 15, y: 15), child.position)
    }

    func testCopyIsDeepAndRelinked() {
        let package = PackageNode()
        let child = ClassNode()
        child.setName("Child")
        package.addChild(child)
        package.setName("Package")

        let copy = package.copy()

        XCTAssertFalse(copy === package)
        XCTAssertEqual("Package", copy.name)
        XCTAssertEqual(1, copy.children.count)
        XCTAssertFalse(copy.children[0] === child, "children must be cloned")
        XCTAssertTrue(copy.children[0].getParent() === copy, "cloned child must be relinked")
        XCTAssertEqual("Child", (copy.children[0] as? ClassNode)?.name)
        // The original is untouched
        XCTAssertTrue(child.getParent() === package)
    }

    func testParentLink() {
        let outer = PackageNode()
        let inner = PackageNode()
        inner.link(outer)
        XCTAssertTrue(inner.hasParent)
        XCTAssertTrue(inner.getParent() === outer)
        inner.unlink()
        XCTAssertFalse(inner.hasParent)
    }
}

/// Port of test/org/jetuml/diagram/nodes/PackageDescriptionNodeTest.java
final class PackageDescriptionNodeTests: XCTestCase {

    func testDefaults() {
        let node = PackageDescriptionNode()
        XCTAssertEqual("", node.name)
        XCTAssertEqual("", node.contents)
        XCTAssertEqual([.name, .contents], node.properties.map(\.name))
    }

    func testContentsBinding() {
        let node = PackageDescriptionNode()
        node.properties.get(.contents).set("package body")
        XCTAssertEqual("package body", node.contents)
        XCTAssertEqual("package body", node.properties.string(.contents))
    }

    func testCopy() {
        let node = PackageDescriptionNode()
        node.setName("P")
        node.setContents("C")
        let copy = node.copy()
        XCTAssertEqual("P", copy.name)
        XCTAssertEqual("C", copy.contents)
    }
}

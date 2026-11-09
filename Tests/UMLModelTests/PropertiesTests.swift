import XCTest
@testable import UMLModel

/// Port of test/org/jetuml/diagram/PropertiesTest.java
final class PropertiesTests: XCTestCase {

    private final class Stub {
        var value = ""
    }

    private let stub = Stub()
    private var properties = Properties()

    private var names: [PropertyName] {
        properties.map(\.name)
    }

    func testEmpty() {
        XCTAssertTrue(properties.isEmpty)
        XCTAssertEqual(0, properties.count)
    }

    func testAddOne() {
        properties.add(
            .aggregationType,
            get: { [stub] in stub.value },
            set: { [stub] value in stub.value = value as? String ?? "" })
        XCTAssertEqual(1, properties.count)
        let property = properties.get(.aggregationType)
        XCTAssertEqual(.aggregationType, property.name)
        XCTAssertEqual("", property.get() as? String)
    }

    func testAddTwo() {
        properties.add(
            .aggregationType,
            get: { [stub] in stub.value },
            set: { [stub] value in stub.value = value as? String ?? "" })
        properties.add(
            .attributes,
            get: { [stub] in stub.value + "X" },
            set: { [stub] value in stub.value = (value as? String ?? "") + "X" })

        XCTAssertEqual(2, properties.count)
        XCTAssertEqual("X", properties.get(.attributes).get() as? String)
        XCTAssertEqual([.aggregationType, .attributes], names)
    }

    func testAddAtZero() {
        properties.addAt(
            .attributes,
            get: { [stub] in stub.value },
            set: { [stub] value in stub.value = value as? String ?? "" },
            0)
        XCTAssertEqual(1, properties.count)
        XCTAssertEqual(.attributes, Array(properties).first?.name)
    }

    func testAddAtZeroOfTwo() {
        properties.add(.attributes, get: { "" }, set: { _ in })
        properties.addAt(.contents, get: { "" }, set: { _ in }, 0)
        XCTAssertEqual([.contents, .attributes], names)
    }

    func testAddAtOneOfTwo() {
        properties.add(.attributes, get: { "" }, set: { _ in })
        properties.addAt(.contents, get: { "" }, set: { _ in }, 1)
        XCTAssertEqual([.attributes, .contents], names)
    }

    func testSetAndGetRoundTrip() {
        properties.add(
            .name,
            get: { [stub] in stub.value },
            set: { [stub] value in stub.value = value as? String ?? "" })
        properties.get(.name).set("JetUML")
        XCTAssertEqual("JetUML", stub.value)
        XCTAssertEqual("JetUML", properties.string(.name))
    }

    func testContains() {
        properties.add(.name, get: { "" }, set: { _ in })
        XCTAssertTrue(properties.contains(.name))
        XCTAssertFalse(properties.contains(.methods))
    }

    func testTypedAccessors() {
        properties.add(.openBottom, get: { true }, set: { _ in })
        properties.add(.name, get: { "A" }, set: { _ in })
        XCTAssertTrue(properties.bool(.openBottom))
        XCTAssertEqual("A", properties.string(.name))
    }
}

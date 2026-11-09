//
//  DiagramCoding.swift
//  UMLExpress
//
//  Port of org.jetuml.persistence.PersistenceService, JsonDecoder, JsonEncoder and the
//  serialization contexts (JetUML 3.10, GPL-3, (C) McGill University).
//
//  The Java implementation uses its own JSON parser to avoid dependencies; the port
//  uses Foundation's JSONSerialization for reading and a small writer for writing
//  (needed to control key order and the compact one-line layout of `.jet` files).
//

import Foundation
import UMLGeometry
import UMLModel
import UMLValidation

/// Errors produced when a diagram cannot be decoded.
public enum DiagramPersistenceError: Error, Equatable {

    /// The file does not contain well-formed JSON.
    case syntactic(String)

    /// The JSON is well formed but cannot be assembled into a diagram.
    case structural(String)

    /// The diagram can be assembled but violates a semantic rule.
    case semantic(String)

    /// A human-readable description, as surfaced by the original `DeserializationException`.
    public var message: String {
        switch self {
        case let .syntactic(message), let .structural(message), let .semantic(message): message
        }
    }

    /// True if this error was detected by the structural checks.
    public var isStructural: Bool {
        if case .structural = self {
            return true
        }
        return false
    }
}

/// Reads and writes diagrams in the JetUML JSON format (schema 3.0).
public enum DiagramCoding {

    /// The version string written into diagram files.
    ///
    /// The original writes the running JetUML version; the file format itself is 3.0
    /// and decoders ignore the value, so the port writes the upstream version it aims
    /// to stay compatible with.
    public nonisolated(unsafe) static var applicationVersion = "3.10"

    // MARK: - Reading

    /// Decodes a diagram from the bytes of a `.jet` file.
    public static func decode(_ data: Data) throws -> Diagram {
        let parsed: Any
        do {
            parsed = try JSONSerialization.jsonObject(with: data, options: [])
        } catch {
            throw DiagramPersistenceError.syntactic("Invalid JSON notation")
        }
        guard let root = parsed as? [String: Any] else {
            throw DiagramPersistenceError.structural("The root of a diagram file must be a JSON object")
        }
        var decoder = try DiagramDecoder(root)
        let diagram = try decoder.decode()
        try validate(diagram)
        return diagram
    }

    /// Runs the semantic validator for the diagram type, mapping violations onto the
    /// error categories of the original `PersistenceService.read`.
    static func validate(_ diagram: Diagram) throws {
        guard let validator = DiagramValidatorFactory.validator(for: diagram) else {
            return
        }
        guard let violation = validator.validate() else {
            return
        }
        throw violation.isStructural
            ? DiagramPersistenceError.structural("Diagram has invalid structure")
            : DiagramPersistenceError.semantic("Diagram has invalid semantics")
    }

    // MARK: - Writing

    /// Encodes a diagram as the bytes of a `.jet` file.
    public static func encode(_ diagram: Diagram) throws -> Data {
        let json = try DiagramEncoder(diagram).encode()
        return Data(json.utf8)
    }
}

// MARK: - Decoding

/// Converts a JSON object into a diagram.
struct DiagramDecoder {

    private static let propertyDiagram = "diagram"
    private static let propertyNodes = "nodes"
    private static let propertyEdges = "edges"
    private static let propertyVersion = "version"
    private static let propertyType = "type"
    private static let propertyX = "x"
    private static let propertyY = "y"
    private static let propertyId = "id"
    private static let propertyChildren = "children"
    private static let propertyStart = "start"
    private static let propertyEnd = "end"

    private let input: [String: Any]
    private var diagram: Diagram
    private var nodesById: [Int: any Node] = [:]
    private var nodes: [any Node] = []

    init(_ input: [String: Any]) throws {
        self.input = input
        // The diagram type is needed immediately; the rest is decoded in `decode()`.
        let name = try DiagramDecoder.string(input, DiagramDecoder.propertyDiagram)
        do {
            self.diagram = Diagram(kind: try DiagramKind.fromName(name))
        } catch {
            throw DiagramPersistenceError.structural("Invalid diagram type: \(name)")
        }
    }

    mutating func decode() throws -> Diagram {
        try extractVersion()
        try decodeNodes()
        try restoreChildren()
        restoreRootNodes()
        try decodeEdges()
        return diagram
    }

    private func extractVersion() throws {
        let version = try DiagramDecoder.string(input, Self.propertyVersion)
        // The version is parsed as an integrity check but not stored (as in the original).
        // `Version.parse` accepts two or three dot-separated integers.
        guard DiagramDecoder.isValidVersion(version) else {
            throw DiagramPersistenceError.structural("Cannot parse version number")
        }
    }

    private mutating func decodeNodes() throws {
        let nodesArray = try DiagramDecoder.array(input, Self.propertyNodes)
        for element in nodesArray {
            guard let object = element as? [String: Any] else {
                throw DiagramPersistenceError.structural("Cannot instantiate serialized object")
            }
            let typeName = try DiagramDecoder.string(object, Self.propertyType)
            guard let node = DiagramElementFactory.makeNode(typeName) else {
                throw DiagramPersistenceError.structural("Unknown node type: \(typeName)")
            }
            node.moveTo(Point(x: try DiagramDecoder.int(object, Self.propertyX),
                              y: try DiagramDecoder.int(object, Self.propertyY)))
            for property in node.properties {
                guard object.keys.contains(property.name.external) else {
                    throw DiagramPersistenceError.structural(
                        "Cannot obtain value of property '\(property.name.external)'")
                }
                property.set(object[property.name.external]!)
            }
            let id = try DiagramDecoder.int(object, Self.propertyId)
            if nodesById[id] != nil {
                throw DiagramPersistenceError.structural("Duplicate node id: \(id)")
            }
            nodesById[id] = node
            nodes.append(node)
        }
    }

    private mutating func restoreChildren() throws {
        let nodesArray = try DiagramDecoder.array(input, Self.propertyNodes)
        for element in nodesArray {
            guard let object = element as? [String: Any] else { continue }
            guard let childrenValue = object[Self.propertyChildren] else { continue }
            guard let children = childrenValue as? [Any] else {
                throw DiagramPersistenceError.structural("'children' must be an array")
            }
            let id = try DiagramDecoder.int(object, Self.propertyId)
            guard let node = nodesById[id] else {
                throw DiagramPersistenceError.structural("Invalid node id found in children nodes")
            }
            for childValue in children {
                guard let childId = childValue as? Int, let child = nodesById[childId] else {
                    throw DiagramPersistenceError.structural("Invalid node id found in children nodes")
                }
                guard node.allowsAsChild(child) else {
                    throw DiagramPersistenceError.structural("Invalid parent-child relation")
                }
                node.addChild(child)
            }
        }
    }

    private mutating func restoreRootNodes() {
        for node in nodes where !node.hasParent {
            diagram.addRootNode(node)
        }
    }

    private mutating func decodeEdges() throws {
        let edgesArray = try DiagramDecoder.array(input, Self.propertyEdges)
        for element in edgesArray {
            guard let object = element as? [String: Any] else {
                throw DiagramPersistenceError.structural("Cannot instantiate serialized object")
            }
            let typeName = try DiagramDecoder.string(object, Self.propertyType)
            guard let edge = DiagramElementFactory.makeEdge(typeName) else {
                throw DiagramPersistenceError.structural("Unknown edge type: \(typeName)")
            }
            for property in edge.properties {
                guard object.keys.contains(property.name.external) else {
                    throw DiagramPersistenceError.structural(
                        "Cannot obtain value of property '\(property.name.external)'")
                }
                property.set(object[property.name.external]!)
            }
            let startId = try DiagramDecoder.int(object, Self.propertyStart)
            let endId = try DiagramDecoder.int(object, Self.propertyEnd)
            guard let start = nodesById[startId], let end = nodesById[endId] else {
                throw DiagramPersistenceError.structural("At least one edge vertex cannot be found")
            }
            edge.connect(start, end)
            diagram.addEdge(edge)
        }
    }

    // MARK: - Value extraction

    /// True if the string is a version of the form `N.N` or `N.N.N` (port of
    /// `Version.parse`).
    static func isValidVersion(_ version: String) -> Bool {
        let components = version.components(separatedBy: ".")
        guard components.count == 2 || components.count == 3 else {
            return false
        }
        return components.allSatisfy { Int($0) != nil }
    }

    static func string(_ object: [String: Any], _ name: String) throws -> String {
        guard let value = object[name] as? String else {
            throw DiagramPersistenceError.structural("Cannot obtain value of property '\(name)'")
        }
        return value
    }

    static func int(_ object: [String: Any], _ name: String) throws -> Int {
        guard let value = object[name] as? Int else {
            throw DiagramPersistenceError.structural("Cannot obtain value of property '\(name)'")
        }
        return value
    }

    static func array(_ object: [String: Any], _ name: String) throws -> [Any] {
        guard let value = object[name] as? [Any] else {
            throw DiagramPersistenceError.structural("Cannot obtain value of property '\(name)'")
        }
        return value
    }
}

// MARK: - Encoding

/// Converts a diagram into JSON notation.
struct DiagramEncoder {

    private let diagram: Diagram
    private var ids: [ObjectIdentifier: Int] = [:]

    init(_ diagram: Diagram) {
        self.diagram = diagram
        // `SerializationContext`: every node of the diagram, in `allNodes()` order.
        for (index, node) in diagram.allNodes.enumerated() {
            ids[ObjectIdentifier(node)] = index
        }
    }

    func encode() throws -> String {
        var parts: [String] = []
        parts.append("\"version\":\(Self.jsonString(DiagramCoding.applicationVersion))")
        parts.append("\"diagram\":\(Self.jsonString(diagram.name))")
        parts.append("\"nodes\":[\(encodeNodes().joined(separator: ","))]")
        parts.append("\"edges\":[\(encodeEdges().joined(separator: ","))]")
        return "{\(parts.joined(separator: ","))}"
    }

    private func encodeNodes() -> [String] {
        diagram.allNodes.map(encodeNode)
    }

    private func encodeNode(_ node: any Node) -> String {
        var parts: [String] = []
        parts.append(contentsOf: encodeProperties(node.properties))
        parts.append("\"id\":\(identifier(of: node))")
        parts.append("\"type\":\(Self.jsonString(String(describing: Swift.type(of: node))))")
        parts.append("\"x\":\(node.position.x)")
        parts.append("\"y\":\(node.position.y)")
        if !node.children.isEmpty {
            let children = node.children.map { "\(identifier(of: $0))" }
            parts.append("\"children\":[\(children.joined(separator: ","))]")
        }
        return "{\(parts.joined(separator: ","))}"
    }

    private func encodeEdges() -> [String] {
        diagram.edges.map { edge in
            var parts: [String] = []
            parts.append(contentsOf: encodeProperties(edge.properties))
            parts.append("\"type\":\(Self.jsonString(String(describing: Swift.type(of: edge))))")
            parts.append("\"start\":\(identifier(of: edge.start()))")
            parts.append("\"end\":\(identifier(of: edge.end()))")
            return "{\(parts.joined(separator: ","))}"
        }
    }

    private func encodeProperties(_ properties: Properties) -> [String] {
        properties.compactMap { property -> String? in
            let value = property.get()
            let key = Self.jsonString(property.name.external)
            switch value {
            case let value as String:
                return "\(key):\(Self.jsonString(value))"
            case let value as Bool:
                return "\(key):\(value)"
            case let value as Int:
                return "\(key):\(value)"
            case let value as any BinaryInteger:
                return "\(key):\(value)"
            default:
                // Java only encodes String, Enum, Integer and Boolean values.
                return nil
            }
        }
    }

    private func identifier(of node: (any Node)?) -> Int {
        guard let node, let id = ids[ObjectIdentifier(node)] else {
            preconditionFailure("node is not part of the diagram")
        }
        return id
    }

    /// Escapes a string as a JSON string literal, as `JsonStringParser.writeJsonString`.
    static func jsonString(_ string: String) -> String {
        var result = "\""
        for character in string.unicodeScalars {
            switch character {
            case "\"": result += "\\\""
            case "\\": result += "\\\\"
            case "\n": result += "\\n"
            case "\r": result += "\\r"
            case "\t": result += "\\t"
            case "\u{08}": result += "\\b"
            case "\u{0C}": result += "\\f"
            default:
                if character.value < 0x20 {
                    result += String(format: "\\u%04x", character.value)
                } else {
                    result.unicodeScalars.append(character)
                }
            }
        }
        return result + "\""
    }
}

// MARK: - Element factory

/// Creates diagram elements from the type names stored in a diagram file.
///
/// The original resolves the names by reflection (`Class.forName`); a registry keeps the
/// port dependency-free and testable.
public enum DiagramElementFactory {

    /// A factory that creates a fresh node of the named type.
    public static func makeNode(_ typeName: String) -> (any Node)? {
        switch typeName {
        case "ClassNode": ClassNode()
        case "InterfaceNode": InterfaceNode()
        case "PackageNode": PackageNode()
        case "PackageDescriptionNode": PackageDescriptionNode()
        case "NoteNode": NoteNode()
        case "StateNode": StateNode()
        case "InitialStateNode": InitialStateNode()
        case "FinalStateNode": FinalStateNode()
        case "ActorNode": ActorNode()
        case "UseCaseNode": UseCaseNode()
        case "ObjectNode": ObjectNode()
        case "FieldNode": FieldNode()
        case "ImplicitParameterNode": ImplicitParameterNode()
        case "CallNode": CallNode()
        case "PointNode": PointNode()
        default: nil
        }
    }

    /// A factory that creates a fresh edge of the named type.
    public static func makeEdge(_ typeName: String) -> (any Edge)? {
        switch typeName {
        case "AggregationEdge": AggregationEdge()
        case "AssociationEdge": AssociationEdge()
        case "DependencyEdge": DependencyEdge()
        case "GeneralizationEdge": GeneralizationEdge()
        case "NoteEdge": NoteEdge()
        case "CallEdge": CallEdge()
        case "ConstructorEdge": ConstructorEdge()
        case "ReturnEdge": ReturnEdge()
        case "ObjectReferenceEdge": ObjectReferenceEdge()
        case "ObjectCollaborationEdge": ObjectCollaborationEdge()
        case "StateTransitionEdge": StateTransitionEdge()
        case "UseCaseAssociationEdge": UseCaseAssociationEdge()
        case "UseCaseDependencyEdge": UseCaseDependencyEdge()
        case "UseCaseGeneralizationEdge": UseCaseGeneralizationEdge()
        default: nil
        }
    }
}

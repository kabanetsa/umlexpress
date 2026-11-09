//
//  EdgeStorage.swift
//  UMLExpress
//
//  Port of org.jetuml.rendering.edges.EdgeStorage
//  (JetUML 3.10, GPL-3, (C) McGill University).
//

import UMLGeometry
import UMLModel

/// Stores the `EdgePath`s of edges, keyed by object identity (the original uses an
/// `IdentityHashMap`).
public final class EdgeStorage {

    private var paths: [ObjectIdentifier: EdgePath] = [:]
    private var order: [any Edge] = []

    public init() {}

    /// Stores `path` for `edge`, replacing any previous path.
    public func store(_ edge: any Edge, _ path: EdgePath) {
        let key = ObjectIdentifier(edge)
        if paths[key] == nil {
            order.append(edge)
        }
        paths[key] = path
    }

    /// True if nothing is stored.
    public var isEmpty: Bool { paths.isEmpty }

    /// The path stored for `edge`.
    /// - Precondition: the edge is stored.
    public func edgePath(_ edge: any Edge) -> EdgePath {
        precondition(contains(edge))
        return paths[ObjectIdentifier(edge)]!
    }

    /// True if `edge` is stored.
    public func contains(_ edge: any Edge) -> Bool {
        paths[ObjectIdentifier(edge)] != nil
    }

    /// All the stored edges connected to `node`.
    public func edgesConnectedTo(_ node: any Node) -> [any Edge] {
        order.filter { edge in
            (edge.start().map { $0 === node } ?? false) || (edge.end().map { $0 === node } ?? false)
        }
    }

    /// False if the point is already a start or end point of a stored edge.
    public func connectionPointIsAvailable(_ point: Point) -> Bool {
        !order.contains { edge in
            guard let path = paths[ObjectIdentifier(edge)] else { return false }
            return path.startPoint == point || path.endPoint == point
        }
    }

    /// Stored edges that share both attached nodes with `edge` ("shared-node edges").
    public func edgesWithSameNodes(_ edge: any Edge) -> [any Edge] {
        guard let edgeStart = edge.start(), let edgeEnd = edge.end() else {
            return []
        }
        return order.filter { other in
            guard let start = other.start(), let end = other.end() else { return false }
            guard !(other === edge) else { return false }
            let startMatches = (start === edgeStart) || (start === edgeEnd)
            let endMatches = (end === edgeStart) || (end === edgeEnd)
            return startMatches && endMatches
        }
    }

    /// Removes everything from storage.
    public func clear() {
        paths.removeAll()
        order.removeAll()
    }
}

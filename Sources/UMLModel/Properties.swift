//
//  Properties.swift
//  UMLExpress
//
//  Port of org.jetuml.diagram.Property and org.jetuml.diagram.Properties
//  (JetUML 3.10, GPL-3, (C) McGill University).
//

/// A property of a diagram element: a name, a getter and a setter.
///
/// Values are boxed as `Any`, mirroring the `Object`-valued Java original. Use the
/// typed accessors on ``Properties`` to avoid manual casts at call sites.
public struct Property {

    public let name: PropertyName
    private let getter: () -> Any
    private let setter: (Any) -> Void

    public init(_ name: PropertyName, get: @escaping () -> Any, set: @escaping (Any) -> Void) {
        self.name = name
        self.getter = get
        self.setter = set
    }

    /// The current value of this property.
    public func get() -> Any {
        getter()
    }

    /// Assigns a new value to this property.
    public func set(_ value: Any) {
        setter(value)
    }
}

/// An ordered collection of the properties of one diagram element.
///
/// Insertion order is significant: it determines the order of fields in the property
/// sheet and of keys in a saved diagram (see the plan, §2.3).
public final class Properties: Sequence {

    private var ordered: [Property] = []
    private var positions: [PropertyName: Int] = [:]

    public init() {}

    /// Adds a property at the end of the list.
    /// - Precondition: the name is not already present.
    public func add(_ name: PropertyName, get: @escaping () -> Any, set: @escaping (Any) -> Void) {
        precondition(!positions.keys.contains(name))
        positions[name] = ordered.count
        ordered.append(Property(name, get: get, set: set))
    }

    /// Inserts a property at `index`, shifting the others down.
    /// - Precondition: the name is not already present; `index` is in `0...count`.
    public func addAt(
        _ name: PropertyName, get: @escaping () -> Any, set: @escaping (Any) -> Void, _ index: Int
    ) {
        precondition(!positions.keys.contains(name))
        precondition(index >= 0 && index <= ordered.count)
        ordered.insert(Property(name, get: get, set: set), at: index)
        reindex()
    }

    /// The property with the given name.
    /// - Precondition: the property is present.
    public func get(_ name: PropertyName) -> Property {
        precondition(positions.keys.contains(name))
        return ordered[positions[name]!]
    }

    /// True iff a property with this name is present.
    public func contains(_ name: PropertyName) -> Bool {
        positions.keys.contains(name)
    }

    public var count: Int { ordered.count }

    public var isEmpty: Bool { ordered.isEmpty }

    public func makeIterator() -> IndexingIterator<[Property]> {
        ordered.makeIterator()
    }

    // MARK: - Typed convenience accessors

    /// The string value of the given property.
    public func string(_ name: PropertyName) -> String {
        get(name).get() as? String ?? ""
    }

    /// The boolean value of the given property.
    public func bool(_ name: PropertyName) -> Bool {
        get(name).get() as? Bool ?? false
    }

    private func reindex() {
        positions.removeAll(keepingCapacity: true)
        for (index, property) in ordered.enumerated() {
            positions[property.name] = index
        }
    }
}

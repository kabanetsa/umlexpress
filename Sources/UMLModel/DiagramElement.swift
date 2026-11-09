//
//  DiagramElement.swift
//  UMLExpress
//
//  Port of org.jetuml.diagram.DiagramElement and
//  org.jetuml.diagram.AbstractDiagramElement (JetUML 3.10, GPL-3, (C) McGill University).
//

/// A type that allows nodes and edges to be treated uniformly.
public protocol DiagramElement: AnyObject {

    /// The properties that define this element.
    var properties: Properties { get }

    /// An independent copy of this element.
    func copy() -> Self
}

/// Base class for nodes and edges: owns the single `Properties` object that
/// describes the element for its whole life cycle.
open class AbstractDiagramElement: DiagramElement {

    /// Built once, on first access.
    ///
    /// The original builds the properties in the constructor and rebuilds them after
    /// cloning; doing it lazily avoids calling an overridable method from `init` and
    /// gives the same "one Properties object per element" invariant.
    ///
    /// The getters/setters registered by subclasses capture `self` unowned: the
    /// `Properties` object is only reachable through its element, so this cannot
    /// outlive it (documented deviation — Swift has no tracing GC).
    public private(set) lazy var properties: Properties = self.buildProperties()

    public required init() {}

    /// Builds the properties object for this element. Subclasses must call
    /// `super.buildProperties()` and add their own properties to the result.
    open func buildProperties() -> Properties {
        Properties()
    }

    /// An independent copy of this element.
    ///
    /// Subclasses must override; the original relies on `Object.clone()`.
    open func copy() -> Self {
        preconditionFailure("\(type(of: self)) must override copy()")
    }
}

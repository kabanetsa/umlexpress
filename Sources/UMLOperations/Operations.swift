//
//  Operations.swift
//  UMLExpress
//
//  Port of org.jetuml.diagram.builder.DiagramOperation, SimpleOperation,
//  CompoundOperation and DiagramOperationProcessor
//  (JetUML 3.10, GPL-3, (C) McGill University).
//

import Foundation

/// An operation that changes a diagram and can be undone.
///
/// Operations are only required to be valid for a single execution and a single undo
/// in a row.
public protocol DiagramOperation: AnyObject {
    /// Executes the operation.
    func execute()
    /// Undoes the operation.
    func undo()
}

/// A simple (non-compound) operation described by a pair of closures.
public final class SimpleOperation: DiagramOperation {

    private let operation: () -> Void
    private let reverse: () -> Void

    public init(_ operation: @escaping () -> Void, reverse: @escaping () -> Void) {
        self.operation = operation
        self.reverse = reverse
    }

    public func execute() {
        operation()
    }

    public func undo() {
        reverse()
    }
}

/// An operation composed of other operations (Composite design pattern).
///
/// Executing runs the sub-operations in order; undoing runs them in reverse order.
public final class CompoundOperation: DiagramOperation {

    private var operations: [any DiagramOperation] = []

    public init() {}

    /// Adds a sub-operation.
    public func add(_ operation: any DiagramOperation) {
        operations.append(operation)
    }

    public func execute() {
        for operation in operations {
            operation.execute()
        }
    }

    public func undo() {
        for operation in operations.reversed() {
            operation.undo()
        }
    }

    /// True if this compound operation contains no sub-operation.
    public var isEmpty: Bool { operations.isEmpty }

    /// The number of sub-operations.
    public var count: Int { operations.count }
}

/// Executes and undoes operations and keeps the history needed for undo/redo and for
/// the "unsaved changes" flag.
public final class DiagramOperationProcessor {

    private var executedOperations: [any DiagramOperation] = []
    private var undoneOperations: [any DiagramOperation] = []
    private var lastSavedOperation: (any DiagramOperation)?

    public init() {}

    /// Executes the operation and records it as executed.
    public func executeNewOperation(_ operation: any DiagramOperation) {
        operation.execute()
        executedOperations.append(operation)
    }

    /// True if the diagram has operations that have not been saved yet.
    public func hasUnsavedOperations() -> Bool {
        guard let lastSavedOperation else {
            return !executedOperations.isEmpty
        }
        guard let last = executedOperations.last else {
            return true
        }
        return !(lastSavedOperation === last)
    }

    /// Indicates that the diagram managed by this processor has been saved.
    public func diagramSaved() {
        lastSavedOperation = executedOperations.last
    }

    /// Adds an already executed operation to the history without executing it.
    public func storeAlreadyExecutedOperation(_ operation: any DiagramOperation) {
        executedOperations.append(operation)
    }

    /// Undoes the last executed operation.
    public func undoLastExecutedOperation() {
        precondition(canUndo)
        guard let operation = executedOperations.popLast() else {
            return
        }
        operation.undo()
        undoneOperations.append(operation)
    }

    /// Re-executes the last undone operation.
    public func redoLastUndoneOperation() {
        precondition(canRedo)
        guard let operation = undoneOperations.popLast() else {
            return
        }
        operation.execute()
        executedOperations.append(operation)
    }

    /// True if there is at least one operation to undo.
    public var canUndo: Bool { !executedOperations.isEmpty }

    /// True if there is at least one operation to redo.
    public var canRedo: Bool { !undoneOperations.isEmpty }
}

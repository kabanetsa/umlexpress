//
//  PropertySheetModel.swift
//  UMLExpress
//
//  Port of the editor-selection logic of org.jetuml.gui.PropertySheet
//  (JetUML 3.10, GPL-3, (C) McGill University).
//
//  The Java class builds JavaFX controls directly; the port separates the description of
//  the editors (this model) from the widgets, so the behaviour can be tested headlessly.
//

import UMLGeometry
import UMLModel
import UMLOperations
import UMLRendering

/// The kind of editor a property needs.
public enum PropertyEditorKind: Equatable, Sendable {
    /// A single-line text field.
    case text
    /// A multi-line text area.
    case multilineText
    /// A checkbox.
    case boolean
    /// A pop-up with fixed options.
    case choice([String])
}

/// One row of the property sheet.
public struct PropertyRow: Equatable, Sendable {
    /// The property being edited.
    public let name: PropertyName
    /// The label shown to the user.
    public let label: String
    /// The editor to use.
    public let kind: PropertyEditorKind
    /// The current value, rendered as text (the boolean is `"true"`/`"false"`).
    public let value: String
}

/// Describes and edits the properties of a diagram element.
public final class PropertySheetModel {

    /// The element being edited.
    public let element: any DiagramElement

    public init(element: any DiagramElement) {
        self.element = element
    }

    /// The rows of the property sheet, in the order of the element's properties.
    public var rows: [PropertyRow] {
        element.properties.map { property in
            PropertyRow(name: property.name,
                        label: Self.label(for: property.name, element: element),
                        kind: Self.kind(for: property, element: element),
                        value: Self.text(of: property.get()))
        }
    }

    /// True if there is nothing to edit.
    public var isEmpty: Bool { rows.isEmpty }

    /// Creates an undoable operation that sets a property.
    public func setValue(_ value: String, for name: PropertyName) -> any DiagramOperation {
        precondition(element.properties.contains(name))
        let property = element.properties.get(name)
        let oldValue = property.get()
        let newValue = Self.value(of: value, for: property)
        return SimpleOperation({ property.set(newValue) }, reverse: { property.set(oldValue) })
    }

    /// Sets a property immediately, without recording an operation.
    ///
    /// The original property sheet applies edits as they are typed and only records a
    /// single compound operation when the dialog closes; this is that "as typed" step.
    public func setRawValue(_ value: String, for name: PropertyName) {
        precondition(element.properties.contains(name))
        let property = element.properties.get(name)
        property.set(Self.value(of: value, for: property))
    }

    /// A snapshot of the current property values, used to compute the operation for a
    /// dialog session (`PropertyChangeTracker` in the original).
    public func snapshot() -> [(name: PropertyName, value: Any)] {
        element.properties.map { ($0.name, $0.get()) }
    }

    /// A compound operation describing every property changed since `snapshot`.
    ///
    /// Empty when nothing changed; the operations restore the previous values when undone.
    public func operation(since snapshot: [(name: PropertyName, value: Any)]) -> CompoundOperation {
        let operation = CompoundOperation()
        for entry in snapshot {
            guard element.properties.contains(entry.name) else { continue }
            let property = element.properties.get(entry.name)
            guard Self.text(of: entry.value) != Self.text(of: property.get()) else { continue }
            let newValue = property.get()
            let oldValue = entry.value
            operation.add(SimpleOperation({ property.set(newValue) },
                                          reverse: { property.set(oldValue) }))
        }
        return operation
    }

    /// The label shown for a property.
    ///
    /// The name of a note node is labelled "Text", as in the original (notes inherit the
    /// `name` property from `NamedNode`).
    static func label(for name: PropertyName, element: any DiagramElement) -> String {
        if Swift.type(of: element) == NoteNode.self && name == .name {
            return "Text"
        }
        return name.visible
    }

    /// The editor for a property.
    static func kind(for property: Property, element: any DiagramElement) -> PropertyEditorKind {
        let value = property.get()
        if value is Bool {
            return .boolean
        }
        if let options = options(for: property.name, element: element) {
            return .choice(options)
        }
        if isMultiline(property.name, element: element) {
            return .multilineText
        }
        return .text
    }

    /// The allowed values of an enumerated property, or `nil` if it is free text.
    ///
    /// Enum-valued properties are stored as their external strings (the same strings that
    /// Java writes into `.jet` files), so the options are listed here.
    static func options(for name: PropertyName, element: any DiagramElement) -> [String]? {
        switch name {
        case .aggregationType:
            return AggregationEdge.AggregationType.allCases.map(\.rawValue)
        case .generalizationType:
            return GeneralizationEdge.GeneralizationType.allCases.map(\.rawValue)
        case .useCaseDependencyType:
            return UseCaseDependencyEdge.UseCaseDependencyType.allCases.map(\.rawValue)
        case .directionality:
            if element is DependencyEdge {
                return DependencyEdge.Directionality.allCases.map(\.rawValue)
            }
            return AssociationEdge.Directionality.allCases.map(\.rawValue)
        default:
            return nil
        }
    }

    /// True if the property is edited in a multi-line text area.
    static func isMultiline(_ name: PropertyName, element: any DiagramElement) -> Bool {
        switch Swift.type(of: element) {
        case is ClassNode.Type, is InterfaceNode.Type:
            return true
        case is PackageDescriptionNode.Type:
            return name == .contents
        case is NoteNode.Type:
            return true
        default:
            return false
        }
    }

    /// The text representation of a property value.
    static func text(of value: Any) -> String {
        switch value {
        case let value as String: value
        case let value as Bool: value ? "true" : "false"
        default: String(describing: value)
        }
    }

    /// The value to assign for a text representation.
    static func value(of text: String, for property: Property) -> Any {
        if property.get() is Bool {
            return text == "true"
        }
        return text
    }
}

extension DiagramCanvasController {

    /// The element to edit, if the selection is exactly one element.
    public var editableElement: (any DiagramElement)? {
        selection.count == 1 ? selection[0] : nil
    }

    /// The model for editing the currently selected element, if there is exactly one.
    public func propertySheetModel() -> PropertySheetModel? {
        guard let element = editableElement else {
            return nil
        }
        return PropertySheetModel(element: element)
    }

    /// Executes a property change so that it can be undone.
    public func applyPropertyChange(_ operation: any DiagramOperation) {
        processor.executeNewOperation(operation)
        changed()
    }

    /// Records a property change that has already been applied.
    ///
    /// The property sheet edits live and registers one compound operation when it closes,
    /// so one undo reverts the whole editing session (as `PropertyEditorDialog` does).
    public func storeAlreadyAppliedPropertyChange(_ operation: any DiagramOperation) {
        processor.storeAlreadyExecutedOperation(operation)
        changed()
    }
}

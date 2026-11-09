//
//  Prototypes.swift
//  UMLExpress
//
//  Port of org.jetuml.diagram.Prototypes (JetUML 3.10, GPL-3, (C) McGill University).
//
//  The prototype instances are shared, immutable-by-convention elements used by the
//  tool palette: tools are created by copying a prototype.
//

/// Prototype objects for creating diagram elements.
///
/// The shared instance is created once and never mutated afterwards (the prototype
/// elements are treated as immutable, as in the original), hence
/// `@unchecked Sendable`.
public final class Prototypes: @unchecked Sendable {

    /// The singleton instance, as in the original (`Prototypes.instance()`).
    public static let shared = Prototypes()

    // Class diagrams
    public let note: any DiagramElement
    public let noteConnector: any DiagramElement
    public let classNode: any DiagramElement
    public let interfaceNode: any DiagramElement
    public let package: any DiagramElement
    public let packageDescription: any DiagramElement
    public let dependency: any DiagramElement
    public let generalization: any DiagramElement
    public let realization: any DiagramElement
    public let association: any DiagramElement
    public let aggregation: any DiagramElement
    public let composition: any DiagramElement

    // Sequence diagrams
    public let implicitParameter: any DiagramElement
    public let methodCall: any DiagramElement
    public let methodReturn: any DiagramElement

    // State diagrams
    public let state: any DiagramElement
    public let startState: any DiagramElement
    public let endState: any DiagramElement
    public let transition: any DiagramElement

    // Object diagrams
    public let object: any DiagramElement
    public let field: any DiagramElement
    public let reference: any DiagramElement
    public let collaboration: any DiagramElement

    // Use case diagrams
    public let actor: any DiagramElement
    public let useCase: any DiagramElement
    public let useCaseAssociation: any DiagramElement
    public let useCaseExtends: any DiagramElement
    public let useCaseIncludes: any DiagramElement
    public let useCaseGeneralization: any DiagramElement

    /// Tooltip/resource keys, keyed by object identity (the original uses an
    /// `IdentityHashMap`).
    private var keys: [ObjectIdentifier: String] = [:]

    private init() {
        note = Prototypes.register(NoteNode(), "note", into: &keys)
        noteConnector = Prototypes.register(NoteEdge(), "note_connector", into: &keys)
        classNode = Prototypes.register(ClassNode(), "class", into: &keys)
        interfaceNode = Prototypes.register(InterfaceNode(), "interface", into: &keys)
        package = Prototypes.register(PackageNode(), "package", into: &keys)
        packageDescription = Prototypes.register(
            PackageDescriptionNode(), "package_description", into: &keys)
        dependency = Prototypes.register(DependencyEdge(), "dependency", into: &keys)
        generalization = Prototypes.register(GeneralizationEdge(), "generalization", into: &keys)
        realization = Prototypes.register(
            GeneralizationEdge(.implementation), "realization", into: &keys)
        association = Prototypes.register(AssociationEdge(), "association", into: &keys)
        aggregation = Prototypes.register(AggregationEdge(), "aggregation", into: &keys)
        composition = Prototypes.register(AggregationEdge(.composition), "composition", into: &keys)

        implicitParameter = Prototypes.register(ImplicitParameterNode(), "implicit_parameter", into: &keys)
        methodCall = Prototypes.register(CallEdge(), "method_call", into: &keys)
        methodReturn = Prototypes.register(ReturnEdge(), "method_return", into: &keys)

        state = Prototypes.register(StateNode(), "state", into: &keys)
        startState = Prototypes.register(InitialStateNode(), "start_state", into: &keys)
        endState = Prototypes.register(FinalStateNode(), "end_state", into: &keys)
        transition = Prototypes.register(StateTransitionEdge(), "transition", into: &keys)

        object = Prototypes.register(ObjectNode(), "object", into: &keys)
        field = Prototypes.register(FieldNode(), "field", into: &keys)
        reference = Prototypes.register(ObjectReferenceEdge(), "reference", into: &keys)
        collaboration = Prototypes.register(ObjectCollaborationEdge(), "collaboration", into: &keys)

        actor = Prototypes.register(ActorNode(), "actor", into: &keys)
        useCase = Prototypes.register(UseCaseNode(), "use_case", into: &keys)
        useCaseAssociation = Prototypes.register(UseCaseAssociationEdge(), "use_case_association", into: &keys)
        useCaseExtends = Prototypes.register(
            UseCaseDependencyEdge(.extend), "use_case_extends", into: &keys)
        useCaseIncludes = Prototypes.register(
            UseCaseDependencyEdge(.include), "use_case_includes", into: &keys)
        useCaseGeneralization = Prototypes.register(
            UseCaseGeneralizationEdge(), "use_case_generalization", into: &keys)
    }

    private static func register(
        _ element: any DiagramElement, _ key: String, into keys: inout [ObjectIdentifier: String]
    ) -> any DiagramElement {
        keys[ObjectIdentifier(element)] = key
        return element
    }

    /// The tooltip associated with a prototype.
    ///
    /// The original reads the localized strings `<key>.tooltip` (and `.verbose`) from
    /// the resource bundle. Localization is not ported yet, so the resource key is
    /// returned instead — see the plan, §2.6 and §10.
    public func tooltip(_ prototype: any DiagramElement, verbose: Bool) -> String {
        guard let key = keys[ObjectIdentifier(prototype)] else {
            return "[tooltip not found]"
        }
        let baseKey = "\(key).tooltip"
        return verbose ? "\(baseKey) | \(baseKey).verbose" : baseKey
    }
}

extension DiagramKind {

    /// The diagram elements available in the tool palette for this diagram type.
    ///
    /// Port of the prototype arrays in `DiagramType`. Order matters: it is the order of
    /// the tools in the palette.
    public var prototypes: [any DiagramElement] {
        let prototypes = Prototypes.shared
        switch self {
        case .class:
            return [
                prototypes.classNode,
                prototypes.interfaceNode,
                prototypes.package,
                prototypes.packageDescription,
                prototypes.note,
                prototypes.dependency,
                prototypes.generalization,
                prototypes.realization,
                prototypes.association,
                prototypes.aggregation,
                prototypes.composition,
                prototypes.noteConnector,
            ]
        case .sequence:
            return [
                prototypes.implicitParameter,
                prototypes.note,
                prototypes.methodCall,
                prototypes.methodReturn,
                prototypes.noteConnector,
            ]
        case .state:
            return [
                prototypes.state,
                prototypes.startState,
                prototypes.endState,
                prototypes.note,
                prototypes.transition,
                prototypes.noteConnector,
            ]
        case .object:
            return [
                prototypes.object,
                prototypes.field,
                prototypes.note,
                prototypes.reference,
                prototypes.collaboration,
                prototypes.noteConnector,
            ]
        case .useCase:
            return [
                prototypes.actor,
                prototypes.useCase,
                prototypes.note,
                prototypes.useCaseAssociation,
                prototypes.useCaseExtends,
                prototypes.useCaseIncludes,
                prototypes.useCaseGeneralization,
                prototypes.noteConnector,
            ]
        }
    }
}

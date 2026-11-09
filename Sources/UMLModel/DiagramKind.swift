//
//  DiagramKind.swift
//  UMLExpress
//
//  Port of the *data* part of org.jetuml.diagram.DiagramType
//  (JetUML 3.10, GPL-3, (C) McGill University).
//
//  Deliberate deviation (§2.2 of the plan): the Java enum also carries factories for
//  builders, renderers and validators, which creates a cycle between the model and the
//  rendering/UI layers. Here `DiagramKind` holds only the data; the factories live in
//  `DiagramTypeRegistry` in the composition layer.
//

/// The types of diagram supported by the application.
public enum DiagramKind: String, CaseIterable, Sendable {

    /// Internal name used in externalized representations (diagram files).
    case `class` = "ClassDiagram"
    case sequence = "SequenceDiagram"
    case state = "StateDiagram"
    case object = "ObjectDiagram"
    case useCase = "UseCaseDiagram"

    /// The suffix (including the dot) that identifies files of this diagram type.
    public var fileExtension: String {
        switch self {
        case .class: ".class"
        case .sequence: ".sequence"
        case .state: ".state"
        case .object: ".object"
        case .useCase: ".usecase"
        }
    }

    /// The name of the diagram type as stored in a diagram file.
    public var name: String { rawValue }

    /// The diagram kind for an external name.
    /// - Throws: `DiagramKindError.invalidName` when the name is not recognized.
    public static func fromName(_ name: String) throws -> DiagramKind {
        guard let kind = DiagramKind(rawValue: name) else {
            throw DiagramKindError.invalidName(name)
        }
        return kind
    }
}

/// Errors produced when resolving diagram kinds.
public enum DiagramKindError: Error, Equatable {
    /// The given string is not the name of a known diagram type.
    case invalidName(String)
}

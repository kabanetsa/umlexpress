//
//  PropertyName.swift
//  UMLExpress
//
//  Port of org.jetuml.diagram.PropertyName (JetUML 3.10, GPL-3, (C) McGill University).
//  Names of the properties that can be attached to a diagram element.
//

/// The names of all possible element properties.
///
/// Listed in alphabetical order, as in the original. The raw value is the external
/// representation stored in `.jet` files; it is intentionally *not* derived from the
/// case name, to stay binary compatible with the Java file format (§2 of the plan).
public enum PropertyName: String, CaseIterable, Sendable {

    case aggregationType
    case attributes
    case contents
    case directionality
    case endLabel
    case generalizationType
    case methods
    case middleLabel
    case name
    case openBottom
    case signal
    case startLabel
    case useCaseDependencyType
    case value

    /// The name of the property as it appears in a diagram file.
    public var external: String {
        switch self {
        case .aggregationType: "Aggregation Type"
        case .attributes: "attributes"
        case .contents: "contents"
        case .directionality: "directionality"
        case .endLabel: "endLabel"
        case .generalizationType: "Generalization Type"
        case .methods: "methods"
        case .middleLabel: "middleLabel"
        case .name: "name"
        case .openBottom: "openBottom"
        case .signal: "signal"
        case .startLabel: "startLabel"
        case .useCaseDependencyType: "Dependency Type"
        case .value: "value"
        }
    }

    /// The name of the property as users should see it: capitalised words.
    ///
    /// The original reads this from the application resource bundle
    /// (`property.<name>`), where the labels are capitalised ("Attributes", "Middle
    /// Label"). Localized resources are not ported yet, so the labels are spelled out
    /// here — see the plan, §2.5/§2.6 and the localization decision in §10. The
    /// `external` names stay untouched, because they are the ones stored in `.jet` files.
    public var visible: String {
        switch self {
        case .aggregationType, .generalizationType, .useCaseDependencyType:
            external
        case .attributes: "Attributes"
        case .contents: "Contents"
        case .directionality: "Directionality"
        case .endLabel: "End Label"
        case .methods: "Methods"
        case .middleLabel: "Middle Label"
        case .name: "Name"
        case .openBottom: "Open Bottom"
        case .signal: "Signal"
        case .startLabel: "Start Label"
        case .value: "Value"
        }
    }
}

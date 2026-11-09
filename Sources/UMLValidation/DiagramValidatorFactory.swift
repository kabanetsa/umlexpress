//
//  DiagramValidatorFactory.swift
//  UMLExpress
//
//  Port of `DiagramType.newValidatorInstanceFor` (JetUML 3.10, GPL-3, (C) McGill University).
//
//  The original keeps the factory in the `DiagramType` enum; here it lives in the
//  validation module, so the model does not depend on validation.
//

import UMLModel

/// Creates the validator for a diagram type.
public enum DiagramValidatorFactory {

    // Implementations live in the per-type validator files; see
    // `OtherDiagramValidators.swift`.
}

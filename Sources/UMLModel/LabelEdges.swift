//
//  LabelEdges.swift
//  UMLExpress
//
//  Port of org.jetuml.diagram.edges.SingleLabelEdge and
//  org.jetuml.diagram.edges.ThreeLabelEdge (JetUML 3.10, GPL-3, (C) McGill University).
//

/// An edge with a single middle label.
open class SingleLabelEdge: AbstractEdge {

    private var labelText = ""

    public func setMiddleLabel(_ newValue: String) {
        labelText = newValue
    }

    public var middleLabel: String { labelText }

    open override func buildProperties() -> Properties {
        let properties = super.buildProperties()
        properties.add(
            .middleLabel,
            get: { [unowned self] in self.labelText },
            set: { [unowned self] value in self.labelText = value as? String ?? "" })
        return properties
    }

    open override func copy() -> Self {
        let duplicate = super.copy()
        duplicate.labelText = labelText
        return duplicate
    }
}

/// An edge with three labels: a start label, a middle label and an end label.
open class ThreeLabelEdge: SingleLabelEdge {

    private var startLabelText = ""
    private var endLabelText = ""

    public func setStartLabel(_ label: String) {
        startLabelText = label
    }

    public func setEndLabel(_ label: String) {
        endLabelText = label
    }

    public var startLabel: String { startLabelText }

    public var endLabel: String { endLabelText }

    open override func buildProperties() -> Properties {
        let properties = super.buildProperties()
        properties.addAt(
            .startLabel,
            get: { [unowned self] in self.startLabelText },
            set: { [unowned self] value in self.startLabelText = value as? String ?? "" },
            0)
        properties.add(
            .endLabel,
            get: { [unowned self] in self.endLabelText },
            set: { [unowned self] value in self.endLabelText = value as? String ?? "" })
        return properties
    }

    open override func copy() -> Self {
        let duplicate = super.copy()
        duplicate.startLabelText = startLabelText
        duplicate.endLabelText = endLabelText
        return duplicate
    }
}

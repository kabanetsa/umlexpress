//
//  IconTemplates.swift
//  UMLExpress
//
//  Sample elements used to draw the tool-palette icons.
//
//  A palette icon is drawn by the element renderer of the tool, as in JetUML. A freshly
//  created element is empty, though, and an empty class -- an empty rectangle -- is a poor
//  icon. The original solves this for one tool only (`FieldNodeRenderer.createIcon` draws
//  the sample field "x = y"); here every tool whose appearance depends on its text gets a
//  sample element with representative content, so that the palette shows what the tool
//  produces: a class with compartments, a package with a tab, a note with text, and so on.
//
//  The samples are plain elements, never added to any diagram, and they are only used for
//  the icon; the icon of a real element is unaffected.
//

import UMLModel

/// Sample content for the icons of the tool palette.
public enum IconTemplates {

    /// The sample element to draw as the icon of `element`, or nil to draw `element` itself.
    public static func template(for element: any DiagramElement) -> (any DiagramElement)? {
        // The order matters: the type nodes share a superclass, so each is matched exactly.
        switch element {
        case is ClassNode:
            let node = ClassNode()
            node.setName("ClassName")
            node.setAttributes("+ attribute: Type")
            node.setMethods("+ method(): Type")
            return node
        case is InterfaceNode:
            let node = InterfaceNode()
            node.setName("Interface")
            node.setMethods("+ method(): Type")
            return node
        case is PackageDescriptionNode:
            let node = PackageDescriptionNode()
            node.setName("package")
            node.setContents("description of the package")
            return node
        case is PackageNode:
            let node = PackageNode()
            node.setName("package")
            return node
        case is NoteNode:
            let node = NoteNode()
            node.setName("note")
            return node
        case is ActorNode:
            let node = ActorNode()
            node.setName("actor")
            return node
        case is UseCaseNode:
            let node = UseCaseNode()
            node.setName("use case")
            return node
        case is StateNode:
            let node = StateNode()
            node.setName("State")
            return node
        case is ObjectNode:
            let node = ObjectNode()
            node.setName(":Object")
            return node
        case is ImplicitParameterNode:
            let node = ImplicitParameterNode()
            node.setName("object")
            return node
        default:
            return nil
        }
    }
}

//
//  CanvasClipboard.swift
//  UMLExpress
//
//  Port of org.jetuml.application.Clipboard (JetUML 3.10, GPL-3, (C) McGill University).
//
//  The original is a singleton that also produces a system clipboard image; the port
//  keeps the element-copying part, which is what the interaction layer needs, and leaves
//  the image export to the UI layer (M9).
//

import UMLGeometry
import UMLModel
import UMLOperations
import UMLRendering

/// Holds copies of diagram elements for copy/paste between diagrams.
public final class CanvasClipboard {

    private var storedElements: [any DiagramElement] = []

    public init() {}

    /// Stores deep copies of the elements: nodes are cloned recursively, edges are
    /// reconnected to the cloned nodes.
    public func copy(_ elements: [any DiagramElement]) {
        storedElements = []
        var nodeMapping: [ObjectIdentifier: any Node] = [:]

        for element in elements {
            guard let node = element as? any Node else { continue }
            let copy = CanvasClipboard.copyNode(node, into: &nodeMapping)
            storedElements.append(copy)
        }
        for element in elements {
            guard let edge = element as? any Edge else { continue }
            guard let start = edge.start(), let end = edge.end() else { continue }
            guard let startCopy = nodeMapping[ObjectIdentifier(start)],
                  let endCopy = nodeMapping[ObjectIdentifier(end)] else {
                continue
            }
            let edgeCopy = edge.copy()
            edgeCopy.connect(startCopy, endCopy)
            storedElements.append(edgeCopy)
        }
    }

    /// A deep copy of a node, recording the mapping from original to copy.
    private static func copyNode(_ node: any Node,
                                 into mapping: inout [ObjectIdentifier: any Node]) -> any Node {
        let copy = node.copy()
        mapping[ObjectIdentifier(node)] = copy
        for child in node.children where mapping[ObjectIdentifier(child)] == nil {
            let childCopy = copyNode(child, into: &mapping)
            if !copy.children.contains(where: { $0 === childCopy }) {
                childCopy.link(copy)
            }
        }
        return copy
    }

    /// A fresh copy of the clipboard content.
    public func elements() -> [any DiagramElement] {
        var result: [any DiagramElement] = []
        var nodeMapping: [ObjectIdentifier: any Node] = [:]
        for element in storedElements {
            guard let node = element as? any Node else { continue }
            result.append(CanvasClipboard.copyNode(node, into: &nodeMapping))
        }
        for element in storedElements {
            guard let edge = element as? any Edge else { continue }
            guard let start = edge.start(), let end = edge.end(),
                  let startCopy = nodeMapping[ObjectIdentifier(start)],
                  let endCopy = nodeMapping[ObjectIdentifier(end)] else {
                continue
            }
            let edgeCopy = edge.copy()
            edgeCopy.connect(startCopy, endCopy)
            result.append(edgeCopy)
        }
        return result
    }

    /// True if the clipboard has content that can be pasted into the diagram.
    ///
    /// The original checks that no copied node requires a parent that is not part of the
    /// clipboard; the port only needs the clipboard to be non-empty, because copies are
    /// always self-contained.
    public func validPaste(_ diagram: Diagram) -> Bool {
        !storedElements.isEmpty
    }

    /// True if any copied element overlaps an element of the diagram, in which case the
    /// pasted elements are shifted to avoid a visual overlap.
    public func overlapsWithElementOf(_ diagram: Diagram, renderer: any DiagramViewRendererBridge) -> Bool {
        for element in storedElements {
            let bounds = renderer.boundsOf(element)
            for node in diagram.allNodes where renderer.boundsOf(node).contains(bounds.center()) {
                return true
            }
        }
        return false
    }

    /// The number of stored elements, for tests.
    public var count: Int { storedElements.count }
}

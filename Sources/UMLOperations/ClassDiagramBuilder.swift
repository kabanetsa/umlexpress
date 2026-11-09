//
//  ClassDiagramBuilder.swift
//  UMLExpress
//
//  Port of org.jetuml.diagram.builder.ClassDiagramBuilder
//  (JetUML 3.10, GPL-3, (C) McGill University).
//

import UMLGeometry
import UMLModel
import UMLRendering

/// Builder for class diagrams: nodes dropped on a package become its children, and note
/// edges attach to point nodes.
public final class ClassDiagramBuilder: DiagramBuilder {

    private static let padding = 10
    private static let topHeight = 20

    public override init(_ renderer: any DiagramViewRenderer) {
        precondition(renderer.diagramModel.diagramKind == .class)
        super.init(renderer)
    }

    /// Convenience initializer that creates the renderer for the diagram.
    public convenience init(_ diagram: Diagram) {
        self.init(ClassDiagramRenderer(diagram: diagram))
    }

    public override func createAddNodeOperation(_ node: any Node, _ requestedPosition: Point) -> any DiagramOperation {
        if Self.validChild(node) {
            if let container = findContainer(diagram.rootNodes, requestedPosition) {
                if container.children.isEmpty {
                    // The node is the first child: position it inside the container.
                    positionNode(node, Point(x: container.position.x + Self.padding,
                                             y: container.position.y + Self.padding + Self.topHeight))
                } else {
                    positionNode(node, requestedPosition)
                }
                return SimpleOperation({ container.addChild(node) },
                                       reverse: { container.removeChild(node) })
            }
        }
        return super.createAddNodeOperation(node, requestedPosition)
    }

    private static func validChild(_ node: any Node) -> Bool {
        node is TypeNode || node is AbstractPackageNode
    }

    /// The innermost package that contains the point, if any. Overlapping packages resolve
    /// to the last one added, which by default is on top.
    private func findContainer(_ nodes: [any Node], _ point: Point) -> PackageNode? {
        var container: PackageNode?
        for node in nodes {
            if let package = node as? PackageNode, renderer.contains(package, point) {
                container = package
            }
        }
        guard let container else {
            return nil
        }
        if container.children.isEmpty {
            return container
        }
        return findContainer(container.children, point) ?? container
    }

    /// Note edges always end on a point node.
    public override func detectEndNode(_ edge: any Edge, _ startNode: any Node, _ end: Point) -> any Node {
        if type(of: edge) == NoteEdge.self, type(of: startNode) != NoteNode.self,
           let endNode = renderer.nodeAt(end), type(of: endNode) == NoteNode.self {
            return endNode
        }
        return super.detectEndNode(edge, startNode, end)
    }

    // MARK: - Packages

    /// The package node that `nodes` could be attached to, if any.
    private func findPackageToAttach(_ nodes: [any Node]) -> PackageNode? {
        precondition(!nodes.isEmpty)
        var rootNodes = diagram.rootNodes
        for node in nodes where diagram.containsAsRoot(node) {
            rootNodes.removeAll { $0 === node }
        }
        let requestedPosition = nodes[0].position
        guard let package = findContainer(rootNodes, requestedPosition) else {
            return nil
        }
        for node in nodes where package === node || package.children.contains(where: { $0 === node }) {
            return nil
        }
        return package
    }

    private static func isLinkable(_ node: any Node) -> Bool {
        validChild(node) && !node.hasParent
    }

    private static func isUnlinkable(_ node: any Node) -> Bool {
        node.hasParent
    }

    /// True if all the nodes could be attached to the package under the first node.
    public func canLinkToPackage(_ nodes: [any Node]) -> Bool {
        guard !nodes.isEmpty else {
            return false
        }
        return nodes.allSatisfy(Self.isLinkable) && findPackageToAttach(nodes) != nil
    }

    /// True if the nodes could be detached from their shared parent.
    public func canUnlinkFromPackage(_ nodes: [any Node]) -> Bool {
        guard !nodes.isEmpty else {
            return false
        }
        return nodes.allSatisfy(Self.isUnlinkable) && sharedParent(nodes) != nil
    }

    private func sharedParent(_ nodes: [any Node]) -> (any Node)? {
        guard let parent = nodes.first?.getParent() else {
            return nil
        }
        for node in nodes where node.getParent() !== parent {
            return nil
        }
        return parent
    }

    /// Creates an operation that attaches the nodes to the package under the first node.
    public func createLinkToPackageOperation(_ nodes: [any Node]) -> any DiagramOperation {
        precondition(canLinkToPackage(nodes))
        guard let package = findPackageToAttach(nodes) else {
            preconditionFailure("no package to attach to")
        }
        return SimpleOperation({
            for node in nodes {
                self.diagram.removeRootNode(node)
                package.addChild(node)
                node.link(package)
            }
        }, reverse: {
            for node in nodes {
                self.diagram.addRootNode(node)
                package.removeChild(node)
            }
        })
    }

    /// Creates an operation that detaches the nodes from their shared parent.
    public func createUnlinkFromPackageOperation(_ nodes: [any Node]) -> any DiagramOperation {
        precondition(canUnlinkFromPackage(nodes))
        guard let parent = sharedParent(nodes) else {
            preconditionFailure("no shared parent")
        }
        let outerParent: (any Node)? = parent.hasParent ? parent.getParent() : nil
        let parentBounds = renderer.packageBounds(parent as! PackageNode)

        if outerParent == nil {
            return SimpleOperation({
                for node in nodes {
                    self.diagram.addRootNode(node)
                    parent.removeChild(node)
                }
                parent.translate(parentBounds.x - parent.position.x, parentBounds.y - parent.position.y)
            }, reverse: {
                for node in nodes {
                    self.diagram.removeRootNode(node)
                    parent.addChild(node)
                }
            })
        } else {
            return SimpleOperation({
                for node in nodes {
                    parent.removeChild(node)
                    outerParent!.addChild(node)
                }
                parent.translate(parentBounds.x - parent.position.x, parentBounds.y - parent.position.y)
            }, reverse: {
                for node in nodes {
                    outerParent!.removeChild(node)
                    parent.addChild(node)
                }
            })
        }
    }
}

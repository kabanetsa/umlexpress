// swift-tools-version: 6.2
import PackageDescription

/// UMLExpress — native macOS UML editor, a Swift port of JetUML 3.10 (GPL-3).
///
/// Module layout (targets are added as they are ported, SwiftPM rejects empty targets):
///   UMLGeometry     Geometry primitives            <- org.jetuml.geom
///   UMLModel        Diagram model                  <- org.jetuml.diagram*
///   UMLValidation   Semantic validation            <- org.jetuml.diagram.validator*
///   UMLRendering    Rendering pipeline             <- org.jetuml.rendering*
///   UMLPersistence  .jet JSON                      <- org.jetuml.persistence*
///   UMLOperations   Builders + undo                <- org.jetuml.diagram.builder*
///   UMLExpress      UI layer                       <- org.jetuml.gui + org.jetuml.application
///   UMLExpressApp   App executable                 <- org.jetuml.JetUML
let package = Package(
    name: "UMLExpress",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "UMLGeometry", targets: ["UMLGeometry"]),
        .library(name: "UMLModel", targets: ["UMLModel"]),
        .library(name: "UMLRendering", targets: ["UMLRendering"]),
        .library(name: "UMLPersistence", targets: ["UMLPersistence"]),
        .library(name: "UMLValidation", targets: ["UMLValidation"]),
        .library(name: "UMLOperations", targets: ["UMLOperations"]),
        .library(name: "UMLInteraction", targets: ["UMLInteraction"]),
        .library(name: "UMLStudio", targets: ["UMLStudio"])
    ],
    targets: [
        .target(name: "UMLGeometry"),
        .target(name: "UMLModel", dependencies: ["UMLGeometry"]),
        .target(name: "UMLRendering", dependencies: ["UMLGeometry", "UMLModel"]),
        .target(name: "UMLPersistence", dependencies: ["UMLGeometry", "UMLModel", "UMLValidation"]),
        .target(name: "UMLValidation", dependencies: ["UMLGeometry", "UMLModel"]),
        .target(name: "UMLOperations", dependencies: ["UMLGeometry", "UMLModel", "UMLRendering"]),
        .target(name: "UMLInteraction",
                dependencies: ["UMLGeometry", "UMLModel", "UMLRendering", "UMLOperations", "UMLValidation"]),
        .target(name: "UMLStudio",
                dependencies: ["UMLGeometry", "UMLModel", "UMLRendering", "UMLOperations",
                               "UMLValidation", "UMLInteraction", "UMLPersistence"],
                resources: [.copy("Resources/Icons16")]),
        .executableTarget(name: "UMLExpressApp", dependencies: ["UMLStudio"]),
        .testTarget(name: "UMLGeometryTests", dependencies: ["UMLGeometry"]),
        .testTarget(name: "UMLModelTests", dependencies: ["UMLModel"]),
        .testTarget(name: "UMLRenderingTests",
                    dependencies: ["UMLRendering", "UMLModel", "UMLPersistence",
                                   "UMLInteraction"]),
        .testTarget(name: "UMLPersistenceTests",
                    dependencies: ["UMLPersistence", "UMLModel", "UMLValidation"],
                    resources: [.copy("Fixtures")]),
        .testTarget(name: "UMLValidationTests", dependencies: ["UMLValidation", "UMLModel"]),
        .testTarget(name: "UMLOperationsTests",
                    dependencies: ["UMLOperations", "UMLModel", "UMLRendering", "UMLPersistence"]),
        .testTarget(name: "UMLAcceptanceTests",
                    dependencies: ["UMLGeometry", "UMLModel", "UMLRendering", "UMLPersistence",
                                   "UMLValidation", "UMLOperations", "UMLInteraction", "UMLStudio"]),
        .testTarget(name: "UMLStudioTests",
                    dependencies: ["UMLStudio", "UMLModel", "UMLRendering", "UMLInteraction",
                                   "UMLOperations", "UMLValidation", "UMLPersistence"]),
        .testTarget(name: "UMLInteractionTests",
                    dependencies: ["UMLInteraction", "UMLModel", "UMLValidation", "UMLRendering",
                                   "UMLOperations"])
    ]
)

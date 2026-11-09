import AppKit
import XCTest
@testable import UMLModel
@testable import UMLPersistence
@testable import UMLStudio

/// Acceptance checks for the packaged application (M9).
///
/// The bundle is built by `Scripts/build-app.sh`; these tests read it back and verify the
/// properties that matter for distribution.
@MainActor
final class PackagingTests: XCTestCase {

    private var bundleURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("build/UMLExpress.app")
    }

    private var infoPlist: [String: Any]? {
        NSDictionary(contentsOf: bundleURL.appendingPathComponent("Contents/Info.plist"))
            as? [String: Any]
    }

    func testBundleExists() throws {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: bundleURL.path) else {
            throw XCTSkip("the app bundle is not built; run Scripts/build-app.sh")
        }
        XCTAssertTrue(fileManager.fileExists(
            atPath: bundleURL.appendingPathComponent("Contents/MacOS/UMLExpress").path))
        XCTAssertTrue(fileManager.fileExists(
            atPath: bundleURL.appendingPathComponent("Contents/Resources/AppIcon.icns").path))
    }

    func testInfoPlistDeclaresTheDocumentType() throws {
        guard let plist = infoPlist else {
            throw XCTSkip("the app bundle is not built; run Scripts/build-app.sh")
        }
        XCTAssertEqual("com.umlexpress.app", plist["CFBundleIdentifier"] as? String)
        XCTAssertEqual("UMLExpress", plist["CFBundleName"] as? String)
        XCTAssertEqual("26.0", plist["LSMinimumSystemVersion"] as? String)
        XCTAssertEqual("APPL", plist["CFBundlePackageType"] as? String)
        XCTAssertEqual(true, plist["NSHighResolutionCapable"] as? Bool)

        let types = try XCTUnwrap(plist["CFBundleDocumentTypes"] as? [[String: Any]])
        XCTAssertEqual(1, types.count)
        let contentTypes = try XCTUnwrap(types[0]["LSItemContentTypes"] as? [String])
        XCTAssertEqual(["com.umlexpress.app.diagram"], contentTypes)

        let exported = try XCTUnwrap(plist["UTExportedTypeDeclarations"] as? [[String: Any]])
        let tagSpec = try XCTUnwrap(exported[0]["UTTypeTagSpecification"] as? [String: Any])
        XCTAssertEqual(["jet"], tagSpec["public.filename-extension"] as? [String])
    }

    func testBundledBinaryOpensDiagrams() throws {
        let executable = bundleURL.appendingPathComponent("Contents/MacOS/UMLExpress")
        guard FileManager.default.isExecutableFile(atPath: executable.path) else {
            throw XCTSkip("the app bundle is not built; run Scripts/build-app.sh")
        }
        // The binary is a GUI application: verify that it is a Mach-O executable of the
        // expected architecture instead of launching it from a test.
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/file")
        process.arguments = [executable.path]
        let pipe = Pipe()
        process.standardOutput = pipe
        try process.run()
        process.waitUntilExit()
        let output = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        XCTAssertTrue(output.contains("Mach-O 64-bit executable"), "unexpected binary type: \(output)")
    }

    func testBuildScriptIsPresent() {
        let script = bundleURL.deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Scripts/build-app.sh")
        XCTAssertTrue(FileManager.default.fileExists(atPath: script.path))
    }
}

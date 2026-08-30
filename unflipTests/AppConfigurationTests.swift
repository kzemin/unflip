import XCTest

@testable import unflip

/// Smoke tests only: they read bundle configuration and constants. Nothing here
/// opens a camera, a window, or a network connection.
final class AppConfigurationTests: XCTestCase {

    private var appInfo: [String: Any] {
        let bundle = Bundle(for: UnflipMenuBarController.self)
        return bundle.infoDictionary ?? [:]
    }

    func testProductNamingIsLowercaseUnflipEverywhere() {
        XCTAssertEqual(UnflipConfiguration.productName, "unflip")
        XCTAssertEqual(UnflipConfiguration.virtualCameraDeviceName, "unflip")
        XCTAssertEqual(appInfo["CFBundleDisplayName"] as? String, "unflip")
        XCTAssertEqual(appInfo["CFBundleName"] as? String, "unflip")
    }

    func testBundleIdentifiersMatchTheContract() {
        XCTAssertEqual(appInfo["CFBundleIdentifier"] as? String, UnflipConfiguration.hostBundleIdentifier)
        XCTAssertTrue(
            UnflipConfiguration.extensionBundleIdentifier.hasPrefix(UnflipConfiguration.hostBundleIdentifier + "."),
            "The extension must stay inside the host identifier namespace."
        )
    }

    func testDeploymentTargetIsMacOS14() {
        XCTAssertEqual(appInfo["LSMinimumSystemVersion"] as? String, UnflipConfiguration.minimumSystemVersion)
    }

    func testMenuBarOnlyConfiguration() {
        XCTAssertEqual(appInfo["LSUIElement"] as? Bool, true, "unflip must not show a Dock icon.")
        XCTAssertEqual(appInfo["NSPrincipalClass"] as? String, "NSApplication")
    }

    func testPrivacyCopyMatchesTheProductContract() {
        XCTAssertEqual(appInfo["NSCameraUsageDescription"] as? String, UnflipConfiguration.Copy.cameraUsage)
        XCTAssertEqual(appInfo["NSCameraUseContinuityCameraDeviceType"] as? Bool, true)
    }

    func testNoAudioOrMicrophonePermissionIsRequested() {
        XCTAssertNil(appInfo["NSMicrophoneUsageDescription"])
    }

    func testOrientationCopyIsExact() {
        XCTAssertEqual(UnflipConfiguration.Copy.mirroredTile, "Cómo te ves vos")
        XCTAssertEqual(UnflipConfiguration.Copy.unmirroredTile, "Cómo te ven los demás")
        XCTAssertEqual(UnflipConfiguration.Copy.publishMirrored, "Mandar a la call la vista espejo")
    }
}

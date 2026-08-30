import SystemExtensions
import XCTest

@testable import unflip

/// Hardware-free: no request is ever submitted to `OSSystemExtensionManager`.
/// The delegate outcomes are driven directly.
@MainActor
final class VirtualCameraActivationTests: XCTestCase {

    private var submitted: [OSSystemExtensionRequest] = []

    private func makeActivation(
        installedInApplications: Bool = true,
        deviceIsPublished: @escaping () -> Bool = { false }
    ) -> VirtualCameraActivation {
        VirtualCameraActivation(
            extensionIdentifier: UnflipConfiguration.extensionBundleIdentifier,
            bundleLocation: URL(fileURLWithPath: installedInApplications
                ? "/Applications/unflip.app"
                : "/Users/someone/Downloads/unflip.app"),
            submit: { [weak self] request in self?.submitted.append(request) },
            deviceIsPublished: deviceIsPublished
        )
    }

    // MARK: - Location

    func testActivatingFromOutsideApplicationsExplainsWhyItCannotWork() {
        let activation = makeActivation(installedInApplications: false)

        activation.activate()

        XCTAssertEqual(activation.state, .failed(UnflipConfiguration.Copy.virtualCameraNeedsApplicationsFolder))
        XCTAssertTrue(submitted.isEmpty, "no point submitting a request macOS will refuse")
    }

    func testActivatingFromApplicationsSubmitsExactlyOneRequest() {
        let activation = makeActivation()

        activation.activate()

        XCTAssertEqual(activation.state, .submitted)
        XCTAssertEqual(submitted.count, 1)
    }

    func testActivatingWhileAlreadyBusyDoesNotSubmitASecondRequest() {
        let activation = makeActivation()

        activation.activate()
        activation.activate()
        activation.markNeedsUserApproval()
        activation.activate()

        XCTAssertEqual(submitted.count, 1)
    }

    // MARK: - Delegate outcomes

    func testNeedsUserApprovalIsSurfacedWithActionableCopy() {
        let activation = makeActivation()
        activation.markNeedsUserApproval()

        XCTAssertEqual(activation.state, .needsUserApproval)
        XCTAssertEqual(activation.state.statusText, UnflipConfiguration.Copy.virtualCameraNeedsApproval)
    }

    func testReplacingAnInstalledVersionIsSurfaced() {
        let activation = makeActivation()
        activation.markReplacing()

        XCTAssertEqual(activation.state, .replacing)
        XCTAssertTrue(activation.state.isBusy)
    }

    func testRebootRequiredIsSurfacedRatherThanClaimingSuccess() {
        let activation = makeActivation(deviceIsPublished: { true })

        activation.finish(with: .willCompleteAfterReboot)

        XCTAssertEqual(activation.state, .needsRestart)
    }

    func testCompletionOnlyClaimsActiveOnceTheDeviceIsReallyPublished() {
        let visible = makeActivation(deviceIsPublished: { true })
        visible.finish(with: .completed)
        XCTAssertEqual(visible.state, .active)
        XCTAssertEqual(visible.state.statusText, "Cámara virtual: unflip")

        let notVisibleYet = makeActivation(deviceIsPublished: { false })
        notVisibleYet.finish(with: .completed)
        XCTAssertEqual(notVisibleYet.state, .installed, "a completed request is not proof a call app can see unflip")
    }

    func testCancellationReturnsToNotInstalledWithoutAnErrorMessage() {
        let activation = makeActivation()
        activation.activate()

        activation.fail(with: NSError(
            domain: OSSystemExtensionErrorDomain,
            code: OSSystemExtensionError.Code.requestCanceled.rawValue
        ))

        XCTAssertEqual(activation.state, .notInstalled)
    }

    func testFailureKeepsTheSystemReasonInTheMessage() {
        let activation = makeActivation()

        activation.fail(with: NSError(
            domain: OSSystemExtensionErrorDomain,
            code: OSSystemExtensionError.Code.validationFailed.rawValue,
            userInfo: [NSLocalizedDescriptionKey: "code signature invalid"]
        ))

        guard case .failed(let message) = activation.state else {
            return XCTFail("expected a failed state, got \(activation.state)")
        }
        XCTAssertTrue(message.contains("code signature invalid"), "the user needs the real reason, got: \(message)")
    }

    // MARK: - Event-driven refresh

    func testRefreshPromotesInstalledToActiveWhenTheDeviceAppears() {
        var published = false
        let activation = makeActivation(deviceIsPublished: { published })

        activation.finish(with: .completed)
        XCTAssertEqual(activation.state, .installed)

        published = true
        activation.refresh()
        XCTAssertEqual(activation.state, .active)
    }

    func testRefreshDemotesActiveWhenTheDeviceDisappears() {
        var published = true
        let activation = makeActivation(deviceIsPublished: { published })

        activation.finish(with: .completed)
        XCTAssertEqual(activation.state, .active)

        published = false
        activation.refresh()
        XCTAssertEqual(activation.state, .installed)
    }

    func testRefreshDoesNotDisturbAnInFlightRequest() {
        let activation = makeActivation(deviceIsPublished: { true })
        activation.markNeedsUserApproval()

        activation.refresh()

        XCTAssertEqual(activation.state, .needsUserApproval)
    }
}

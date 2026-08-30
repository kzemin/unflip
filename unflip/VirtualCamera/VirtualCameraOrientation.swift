import Foundation

/// What unflip publishes through the virtual camera. Typed rather than a loose
/// `isMirrored` boolean so the outgoing orientation is never confused with the
/// preview's presentation mirroring, which is a different thing entirely.
///
/// The MVP exposes only `.mirrored`: it is the orientation that changes what
/// other people see. `.unmirrored` exists because the model needs both ends of
/// the choice, but it is deliberately not offered in the UI — a physical camera
/// already supplies that orientation to call apps.
enum VirtualCameraOrientation: String, CaseIterable {
    case mirrored
    case unmirrored

    /// The resolved product decision, from `docs/product-contract.md`.
    static let published = VirtualCameraOrientation.mirrored

    /// Whether producing this orientation requires reflecting the captured
    /// frame horizontally. Capture output is unmirrored to begin with.
    var requiresHorizontalReflection: Bool { self == .mirrored }

    /// Only the mirrored action has UI in the MVP.
    var isOfferedInMVP: Bool { self == .mirrored }

    var controlTitle: String {
        switch self {
        case .mirrored: return UnflipConfiguration.Copy.publishMirrored
        case .unmirrored: return UnflipConfiguration.Copy.publishUnmirrored
        }
    }
}

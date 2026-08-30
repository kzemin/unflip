import AVFoundation
import Foundation

/// Immutable, hardware-free description of one physical camera. Identity is the
/// device's `uniqueID`, which survives reconnection; `localizedName` is what the
/// user sees and is never replaced with a generic label.
struct CameraDeviceDescriptor: Identifiable, Equatable, Hashable {

    /// Used only for ordering the picker, never for renaming a device.
    enum Category: Int, Comparable, CaseIterable {
        case builtIn = 0
        case continuity = 1
        case external = 2
        case other = 3

        static func < (lhs: Category, rhs: Category) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    let uniqueID: String
    let localizedName: String
    let category: Category

    var id: String { uniqueID }
}

extension CameraDeviceDescriptor {

    init(device: AVCaptureDevice) {
        self.init(
            uniqueID: device.uniqueID,
            localizedName: device.localizedName,
            category: Category(deviceType: device.deviceType)
        )
    }

    /// Ordered for display, with the `unflip` virtual camera removed so the app
    /// can never capture its own output.
    static func presentable(_ descriptors: [CameraDeviceDescriptor]) -> [CameraDeviceDescriptor] {
        descriptors
            .filter { !$0.isReservedVirtualCamera }
            .sorted { lhs, rhs in
                lhs.category == rhs.category
                    ? lhs.localizedName.localizedStandardCompare(rhs.localizedName) == .orderedAscending
                    : lhs.category < rhs.category
            }
    }

    /// Keeps the current selection when that camera is still present, otherwise
    /// falls back predictably to built-in, then Continuity, then external.
    static func selection(preferring wanted: String?, from devices: [CameraDeviceDescriptor]) -> String? {
        if let wanted, devices.contains(where: { $0.uniqueID == wanted }) { return wanted }
        return presentable(devices).first?.uniqueID
    }

    var isReservedVirtualCamera: Bool {
        uniqueID.range(
            of: UnflipConfiguration.reservedVirtualCameraDeviceID,
            options: .caseInsensitive
        ) != nil
    }
}

extension CameraDeviceDescriptor.Category {

    init(deviceType: AVCaptureDevice.DeviceType) {
        switch deviceType {
        case .builtInWideAngleCamera: self = .builtIn
        case .continuityCamera: self = .continuity
        case .external: self = .external
        default: self = .other
        }
    }
}

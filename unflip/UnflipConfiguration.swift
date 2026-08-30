import Foundation

/// Single source of truth for values that must stay identical between the app,
/// the Camera Extension, the Info.plist files, and the product contract in
/// `docs/product-contract.md`. `UnflipConfigurationTests` fails if they drift.
enum UnflipConfiguration {

    /// Product, menu-bar and virtual-camera device name. Always lowercase.
    static let productName = "unflip"

    /// Name other apps see in their camera picker.
    static let virtualCameraDeviceName = productName

    static let hostBundleIdentifier = "com.kzemin.unflip"
    static let extensionBundleIdentifier = "com.kzemin.unflip.camera"

    static let minimumSystemVersion = "14.0"

    /// Exact rioplatense strings from the product contract.
    enum Copy {
        static let mirroredTile = "Cómo te ves vos"
        static let unmirroredTile = "Cómo te ven los demás"
        static let publishMirrored = "Mandar a la call la vista espejo"
        static let cameraUsage = "unflip usa la cámara solo en esta Mac para mostrarte las dos vistas y, si lo activás, mandar el video a Zoom o Meet."
        static let systemExtensionUsage = "unflip instala una cámara virtual para que otras apps puedan usar el video ya dado vuelta."
        static let preparation = "unflip — preparación"
        static let extensionInactive = "Cámara virtual: todavía no"
        static let quit = "Salir de unflip"
    }
}

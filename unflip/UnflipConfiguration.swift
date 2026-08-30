import Foundation

/// Single source of truth for values that must stay identical between the app,
/// the Camera Extension, the Info.plist files, and the product contract in
/// `docs/product-contract.md`. `AppConfigurationTests` fails if they drift.
enum UnflipConfiguration {

    /// Product, menu-bar and virtual-camera device name. Always lowercase.
    static let productName = "unflip"

    /// Name other apps see in their camera picker.
    static let virtualCameraDeviceName = productName

    static let hostBundleIdentifier = "com.kzemin.unflip"
    static let extensionBundleIdentifier = "com.kzemin.unflip.camera"

    static let minimumSystemVersion = "14.0"

    /// Must stay equal to `UnflipIdentity.deviceID` in
    /// `unflipCamera/UnflipProviderSource.swift`. The host filters this device
    /// out of its own source list so unflip can never capture its own output.
    static let reservedVirtualCameraDeviceID = "3F1A6C2E-0B7D-4E9A-9C41-5F6A7B8C9D01"

    /// Exact rioplatense strings from the product contract.
    enum Copy {
        static let mirroredTile = "Cómo te ves vos"
        static let unmirroredTile = "Cómo te ven los demás"
        static let publishMirrored = "Mandar a la call la vista espejo"
        static let cameraUsage = "unflip usa la cámara solo en esta Mac para mostrarte las dos vistas y, si lo activás, mandar el video a Zoom o Meet."
        static let systemExtensionUsage = "unflip instala una cámara virtual para que otras apps puedan usar el video ya dado vuelta."
        static let footer = "Elegí “unflip” como cámara en Zoom o Meet."

        static let sourceLabel = "Cámara"
        static let virtualCameraOff = "Cámara virtual: apagada"

        static let permissionDenied = "unflip necesita permiso para usar la cámara."
        static let permissionRestricted = "El permiso de cámara está bloqueado en esta Mac."
        static let openSystemSettings = "Abrir Ajustes del Sistema"
        static let noCameras = "No encontramos ninguna cámara."
        static let captureFailed = "No pudimos abrir esa cámara."
        static let waitingForCamera = "Prendiendo la cámara…"

        static let menuOpen = "Abrir unflip"
        static let menuInstallExtension = "Instalar / activar cámara virtual"
        static let quit = "Salir"
    }

    /// Deep link to the camera privacy pane. Opened only on an explicit click.
    static let cameraPrivacySettingsURL = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera"
    )!
}

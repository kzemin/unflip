import AVFoundation
import SwiftUI

/// One `AVCaptureVideoPreviewLayer` per tile, both observing the same capture
/// session. Mirroring lives on each preview connection, so only presentation
/// differs — the session's own output stays unmirrored for Plan 003.
struct CameraPreviewView: NSViewRepresentable {

    let session: AVCaptureSession
    let mirrored: Bool

    func makeNSView(context: Context) -> CameraPreviewNSView {
        let view = CameraPreviewNSView()
        view.configure(session: session, mirrored: mirrored)
        return view
    }

    func updateNSView(_ nsView: CameraPreviewNSView, context: Context) {
        nsView.configure(session: session, mirrored: mirrored)
    }

    static func dismantleNSView(_ nsView: CameraPreviewNSView, coordinator: ()) {
        nsView.detach()
    }
}

final class CameraPreviewNSView: NSView {

    private let previewLayer = AVCaptureVideoPreviewLayer()
    private var mirrored = false
    private var startObserver: NSObjectProtocol?

    init() {
        super.init(frame: .zero)
        layer = previewLayer
        wantsLayer = true
        layerContentsRedrawPolicy = .duringViewResize
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.backgroundColor = NSColor.black.cgColor
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("unflip builds no nibs") }

    deinit {
        if let startObserver { NotificationCenter.default.removeObserver(startObserver) }
    }

    func configure(session: AVCaptureSession, mirrored: Bool) {
        self.mirrored = mirrored

        if previewLayer.session !== session {
            previewLayer.session = session
            observeStart(of: session)
        }
        applyMirroring()
    }

    func detach() {
        previewLayer.session = nil
        if let startObserver { NotificationCenter.default.removeObserver(startObserver) }
        startObserver = nil
    }

    /// The layer only has a connection once the session has a video input, and
    /// that connection is rebuilt whenever the input changes. Re-apply on every
    /// SwiftUI update and again when the session actually starts.
    private func applyMirroring() {
        guard let connection = previewLayer.connection, connection.isVideoMirroringSupported else { return }
        connection.automaticallyAdjustsVideoMirroring = false
        connection.isVideoMirrored = mirrored
    }

    private func observeStart(of session: AVCaptureSession) {
        if let startObserver { NotificationCenter.default.removeObserver(startObserver) }
        startObserver = NotificationCenter.default.addObserver(
            forName: .AVCaptureSessionDidStartRunning,
            object: session,
            queue: .main
        ) { [weak self] _ in
            self?.applyMirroring()
        }
    }
}

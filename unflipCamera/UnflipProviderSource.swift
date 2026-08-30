import CoreMediaIO
import Foundation
import IOKit.audio
import os.log

// Plan 001 scope: the extension only has to compile, embed, and expose a device
// named `unflip`. Plan 003 replaces the placeholder frame source with real
// frames bridged from the host app's capture session over a CMIO sink stream.

/// Hard-coded so the published device keeps one identity across launches and
/// reinstalls. Never replace these with `UUID()`.
enum UnflipIdentity {
    static let deviceID = UUID(uuidString: "3F1A6C2E-0B7D-4E9A-9C41-5F6A7B8C9D01")!
    static let sourceStreamID = UUID(uuidString: "3F1A6C2E-0B7D-4E9A-9C41-5F6A7B8C9D02")!
    /// Reserved now so the sink stream Plan 003 Step 3 adds keeps one identity
    /// from the first release. Never regenerate these.
    static let sinkStreamID = UUID(uuidString: "3F1A6C2E-0B7D-4E9A-9C41-5F6A7B8C9D03")!
    static let deviceName = "unflip"
    static let manufacturer = "unflip"
    static let model = "unflip"
}

private let frameRate: Int32 = 30
private let frameWidth: Int32 = 1280
private let frameHeight: Int32 = 720

final class UnflipDeviceSource: NSObject, CMIOExtensionDeviceSource {

    private(set) var device: CMIOExtensionDevice!

    private var streamSource: UnflipStreamSource!
    private var streamingCounter: UInt32 = 0
    private var timer: DispatchSourceTimer?
    private let timerQueue = DispatchQueue(
        label: "io.unflip.camera.frames",
        qos: .userInteractive,
        target: .global(qos: .userInteractive)
    )

    private var videoDescription: CMFormatDescription!
    private var bufferPool: CVPixelBufferPool!
    private let bufferAuxAttributes: NSDictionary = [kCVPixelBufferPoolAllocationThresholdKey: 5]
    private var cachedTestPattern: CVPixelBuffer?

    init(localizedName: String) {
        super.init()

        device = CMIOExtensionDevice(
            localizedName: localizedName,
            deviceID: UnflipIdentity.deviceID,
            legacyDeviceID: nil,
            source: self
        )

        CMVideoFormatDescriptionCreate(
            allocator: kCFAllocatorDefault,
            codecType: kCVPixelFormatType_32BGRA,
            width: frameWidth,
            height: frameHeight,
            extensions: nil,
            formatDescriptionOut: &videoDescription
        )

        let pixelBufferAttributes: NSDictionary = [
            kCVPixelBufferWidthKey: frameWidth,
            kCVPixelBufferHeightKey: frameHeight,
            kCVPixelBufferPixelFormatTypeKey: videoDescription.mediaSubType,
            kCVPixelBufferIOSurfacePropertiesKey: [:] as NSDictionary,
        ]
        CVPixelBufferPoolCreate(kCFAllocatorDefault, nil, pixelBufferAttributes, &bufferPool)

        let format = CMIOExtensionStreamFormat(
            formatDescription: videoDescription,
            maxFrameDuration: CMTime(value: 1, timescale: frameRate),
            minFrameDuration: CMTime(value: 1, timescale: frameRate),
            validFrameDurations: nil
        )

        streamSource = UnflipStreamSource(
            localizedName: "unflip.video",
            streamID: UnflipIdentity.sourceStreamID,
            streamFormat: format,
            device: device
        )

        do {
            try device.addStream(streamSource.stream)
        } catch {
            fatalError("Failed to add stream: \(error.localizedDescription)")
        }
    }

    var availableProperties: Set<CMIOExtensionProperty> {
        [.deviceTransportType, .deviceModel]
    }

    func deviceProperties(forProperties properties: Set<CMIOExtensionProperty>) throws -> CMIOExtensionDeviceProperties {
        let properties1 = CMIOExtensionDeviceProperties(dictionary: [:])
        if properties.contains(.deviceTransportType) {
            properties1.transportType = kIOAudioDeviceTransportTypeVirtual
        }
        if properties.contains(.deviceModel) {
            properties1.model = UnflipIdentity.model
        }
        return properties1
    }

    func setDeviceProperties(_ deviceProperties: CMIOExtensionDeviceProperties) throws {
        // No settable device properties in the MVP.
    }

    func startStreaming() {
        guard bufferPool != nil else { return }
        streamingCounter += 1
        guard timer == nil else { return }

        let timer = DispatchSource.makeTimerSource(flags: .strict, queue: timerQueue)
        timer.schedule(deadline: .now(), repeating: 1.0 / Double(frameRate), leeway: .milliseconds(1))
        timer.setEventHandler { [weak self] in self?.sendTestFrame() }
        timer.resume()
        self.timer = timer
    }

    func stopStreaming() {
        if streamingCounter > 1 {
            streamingCounter -= 1
            return
        }
        streamingCounter = 0
        timer?.cancel()
        timer = nil
    }

    /// Plan 003 Step 2: a deterministic, deliberately asymmetric test pattern.
    /// Asymmetric so that "is the published frame mirrored?" is answerable by
    /// looking at it — the red bar sits on the left of the unmirrored frame.
    /// Plan 003 Step 3 replaces this with host frames and a black fallback.
    private func sendTestFrame() {
        guard let pattern = testPattern() else { return }

        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferPoolCreatePixelBufferWithAuxAttributes(
            kCFAllocatorDefault, bufferPool, bufferAuxAttributes, &pixelBuffer
        )
        guard status == kCVReturnSuccess, let pixelBuffer else {
            os_log(.error, "unflip: out of pixel buffers (%d)", status)
            return
        }

        // ponytail: one memcpy of a pre-rendered pattern per frame rather than
        // redrawing it. Step 3 replaces the copy source with the host frame.
        CVPixelBufferLockBaseAddress(pattern, .readOnly)
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        if let source = CVPixelBufferGetBaseAddress(pattern),
           let destination = CVPixelBufferGetBaseAddress(pixelBuffer) {
            memcpy(destination, source, CVPixelBufferGetBytesPerRow(pattern) * CVPixelBufferGetHeight(pattern))
        }
        CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
        CVPixelBufferUnlockBaseAddress(pattern, .readOnly)

        send(pixelBuffer)
    }

    private func send(_ pixelBuffer: CVPixelBuffer) {
        var timing = CMSampleTimingInfo()
        timing.presentationTimeStamp = CMClockGetTime(CMClockGetHostTimeClock())

        var sampleBuffer: CMSampleBuffer?
        let err = CMSampleBufferCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            dataReady: true,
            makeDataReadyCallback: nil,
            refcon: nil,
            formatDescription: videoDescription,
            sampleTiming: &timing,
            sampleBufferOut: &sampleBuffer
        )
        guard err == noErr, let sampleBuffer else { return }

        streamSource.stream.send(
            sampleBuffer,
            discontinuity: [],
            hostTimeInNanoseconds: UInt64(timing.presentationTimeStamp.seconds * Double(NSEC_PER_SEC))
        )
    }

    /// Rendered once and reused.
    private func testPattern() -> CVPixelBuffer? {
        if let cachedTestPattern { return cachedTestPattern }

        var buffer: CVPixelBuffer?
        let attributes: NSDictionary = [kCVPixelBufferIOSurfacePropertiesKey: [:] as NSDictionary]
        guard CVPixelBufferCreate(
            kCFAllocatorDefault, Int(frameWidth), Int(frameHeight),
            kCVPixelFormatType_32BGRA, attributes, &buffer
        ) == kCVReturnSuccess, let buffer else { return nil }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard let base = CVPixelBufferGetBaseAddress(buffer) else { return nil }

        let rowBytes = CVPixelBufferGetBytesPerRow(buffer)
        let width = Int(frameWidth)
        let height = Int(frameHeight)
        let barWidth = width / 8

        for y in 0..<height {
            let row = base.advanced(by: y * rowBytes).assumingMemoryBound(to: UInt32.self)
            for x in 0..<width {
                if x < barWidth {
                    row[x] = 0xFFE0_3030            // red bar, left edge only
                } else {
                    let blue = UInt32(x * 255 / width)
                    row[x] = 0xFF20_2020 | blue     // dark grey, bluer to the right
                }
            }
        }

        cachedTestPattern = buffer
        return buffer
    }
}

enum UnflipStreamError: Error {
    case unexpectedDeviceSource
}

final class UnflipStreamSource: NSObject, CMIOExtensionStreamSource {

    private(set) var stream: CMIOExtensionStream!
    let device: CMIOExtensionDevice
    private let streamFormat: CMIOExtensionStreamFormat

    init(localizedName: String, streamID: UUID, streamFormat: CMIOExtensionStreamFormat, device: CMIOExtensionDevice) {
        self.device = device
        self.streamFormat = streamFormat
        super.init()
        stream = CMIOExtensionStream(
            localizedName: localizedName,
            streamID: streamID,
            direction: .source,
            clockType: .hostTime,
            source: self
        )
    }

    var formats: [CMIOExtensionStreamFormat] { [streamFormat] }

    var activeFormatIndex: Int = 0

    var availableProperties: Set<CMIOExtensionProperty> {
        [.streamActiveFormatIndex, .streamFrameDuration]
    }

    func streamProperties(forProperties properties: Set<CMIOExtensionProperty>) throws -> CMIOExtensionStreamProperties {
        let streamProperties = CMIOExtensionStreamProperties(dictionary: [:])
        if properties.contains(.streamActiveFormatIndex) {
            streamProperties.activeFormatIndex = 0
        }
        if properties.contains(.streamFrameDuration) {
            streamProperties.frameDuration = CMTime(value: 1, timescale: frameRate)
        }
        return streamProperties
    }

    func setStreamProperties(_ streamProperties: CMIOExtensionStreamProperties) throws {
        if let activeFormatIndex = streamProperties.activeFormatIndex, activeFormatIndex == 0 {
            self.activeFormatIndex = activeFormatIndex
        }
    }

    func authorizedToStartStream(for client: CMIOExtensionClient) -> Bool { true }

    func startStream() throws {
        guard let deviceSource = device.source as? UnflipDeviceSource else {
            throw UnflipStreamError.unexpectedDeviceSource
        }
        deviceSource.startStreaming()
    }

    func stopStream() throws {
        guard let deviceSource = device.source as? UnflipDeviceSource else {
            throw UnflipStreamError.unexpectedDeviceSource
        }
        deviceSource.stopStreaming()
    }
}

final class UnflipProviderSource: NSObject, CMIOExtensionProviderSource {

    private(set) var provider: CMIOExtensionProvider!
    private var deviceSource: UnflipDeviceSource!

    init(clientQueue: DispatchQueue?) {
        super.init()
        provider = CMIOExtensionProvider(source: self, clientQueue: clientQueue)
        deviceSource = UnflipDeviceSource(localizedName: UnflipIdentity.deviceName)
        do {
            try provider.addDevice(deviceSource.device)
        } catch {
            fatalError("Failed to add device: \(error.localizedDescription)")
        }
    }

    func connect(to client: CMIOExtensionClient) throws {}

    func disconnect(from client: CMIOExtensionClient) {}

    var availableProperties: Set<CMIOExtensionProperty> {
        [.providerManufacturer]
    }

    func providerProperties(forProperties properties: Set<CMIOExtensionProperty>) throws -> CMIOExtensionProviderProperties {
        let providerProperties = CMIOExtensionProviderProperties(dictionary: [:])
        if properties.contains(.providerManufacturer) {
            providerProperties.manufacturer = UnflipIdentity.manufacturer
        }
        return providerProperties
    }

    func setProviderProperties(_ providerProperties: CMIOExtensionProviderProperties) throws {
        // No settable provider properties in the MVP.
    }
}

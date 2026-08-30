import AppKit
import SwiftUI

struct UnflipPopoverView: View {

    @ObservedObject var camera: CameraSessionController

    private static let background = Color(red: 0x0B / 255, green: 0x0B / 255, blue: 0x0C / 255)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                tile(title: UnflipConfiguration.Copy.mirroredTile, mirrored: true)
                tile(title: UnflipConfiguration.Copy.unmirroredTile, mirrored: false)
                overflowMenu
            }

            if camera.permission == .denied || camera.permission == .restricted {
                Button(UnflipConfiguration.Copy.openSystemSettings) {
                    NSWorkspace.shared.open(UnflipConfiguration.cameraPrivacySettingsURL)
                }
                .controlSize(.small)
            }

            sourcePicker
            virtualCameraRow

            Text(UnflipConfiguration.Copy.footer)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(width: 440)
        .background(Self.background)
    }

    // MARK: - Tiles

    private func tile(title: String, mirrored: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            ZStack {
                Color.black
                if let session = camera.previewSession, camera.status == .running {
                    CameraPreviewView(session: session, mirrored: mirrored)
                } else {
                    Text(camera.message ?? UnflipConfiguration.Copy.waitingForCamera)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(8)
                }
            }
            .aspectRatio(16.0 / 9.0, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .accessibilityLabel(title)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Controls

    private var sourcePicker: some View {
        Picker(UnflipConfiguration.Copy.sourceLabel, selection: selectionBinding) {
            ForEach(camera.devices) { device in
                Text(device.localizedName).tag(device.uniqueID)
            }
        }
        .pickerStyle(.menu)
        .controlSize(.small)
        .disabled(camera.devices.count < 2)
    }

    private var selectionBinding: Binding<String> {
        Binding(
            get: { camera.selectedDeviceID ?? "" },
            set: { newValue in
                guard !newValue.isEmpty, newValue != camera.selectedDeviceID else { return }
                camera.select(deviceUniqueID: newValue)
            }
        )
    }

    /// Plan 003 turns this on. Shown disabled so the popover's final shape is
    /// visible now and does not shift when the extension lands.
    private var virtualCameraRow: some View {
        VStack(alignment: .leading, spacing: 2) {
            Toggle(UnflipConfiguration.Copy.publishMirrored, isOn: .constant(false))
                .toggleStyle(.switch)
                .controlSize(.small)
                .disabled(true)

            Text(UnflipConfiguration.Copy.virtualCameraOff)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var overflowMenu: some View {
        Menu {
            Button(UnflipConfiguration.Copy.menuInstallExtension) {}
                .disabled(true)
            Divider()
            Button(UnflipConfiguration.Copy.quit) { NSApplication.shared.terminate(nil) }
        } label: {
            Image(systemName: "ellipsis")
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: 22)
        .accessibilityLabel("Más opciones")
    }
}

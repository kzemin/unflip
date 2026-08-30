import SwiftUI

/// Plan 001 shell only: no camera, no previews, no toggle yet. Plan 002
/// replaces the placeholder body with the two 16:9 tiles.
struct UnflipPopoverView: View {

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(UnflipConfiguration.Copy.preparation)
                .font(.headline)

            Label(UnflipConfiguration.Copy.extensionInactive, systemImage: "video.slash")
                .foregroundStyle(.secondary)
                .font(.callout)

            Divider()

            Button(UnflipConfiguration.Copy.quit) {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding(16)
        .frame(width: 280, alignment: .leading)
    }
}

#Preview {
    UnflipPopoverView()
}

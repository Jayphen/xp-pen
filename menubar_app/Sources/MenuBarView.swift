import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var device: DeviceManager
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: XPSpacing.s3) {
            // Status
            HStack(spacing: XPSpacing.s2) {
                Circle()
                    .fill(device.isConnected
                        ? LinearGradient(colors: [.xpPrimary, .xpPrimaryContainer], startPoint: .topLeading, endPoint: .bottomTrailing)
                        : LinearGradient(colors: [Color.xpOnSurfaceVariant.opacity(0.3)], startPoint: .top, endPoint: .bottom)
                    )
                    .frame(width: 8, height: 8)

                Text(device.isConnected ? device.transport : "Disconnected")
                    .font(XPFont.titleMd())
                    .foregroundColor(.xpOnSurface)
                    .tracking(-0.02 * 17)
            }

            if let event = device.lastEvent, !event.isRelease, !event.isScroll {
                Text(device.labelFor(key: event.key))
                    .font(XPFont.labelSm())
                    .foregroundColor(.xpOnSurfaceVariant)
            }

            // Actions
            VStack(spacing: XPSpacing.s2) {
                Button {
                    openWindow(id: "mapping")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        NSApp.activate(ignoringOtherApps: true)
                        NSApp.windows.first { $0.isVisible && $0.title == "Button Mapping" }?.orderFrontRegardless()
                    }
                } label: {
                    HStack {
                        Image(systemName: "slider.horizontal.3")
                        Text("Button Mapping")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(XPPrimaryButtonStyle())

                Button {
                    NSApp.terminate(nil)
                } label: {
                    Text("Quit")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(XPTertiaryButtonStyle())
            }
        }
        .padding(XPSpacing.s4)
        .frame(width: 240)
        .background(Color.xpSurface)
    }
}

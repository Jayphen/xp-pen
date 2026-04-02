import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var device: DeviceManager
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Circle()
                    .fill(device.isConnected ? .green : .red)
                    .frame(width: 8, height: 8)
                Text(device.isConnected ? "Connected via \(device.transport)" : "Disconnected")
                    .font(.headline)
            }

            if let event = device.lastEvent, !event.isRelease, !event.isScroll {
                Text("Last: \(device.labelFor(key: event.key))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            Button("Button Mapping...") {
                openWindow(id: "mapping")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    NSApp.activate(ignoringOtherApps: true)
                    NSApp.windows.first { $0.isVisible && $0.title == "Button Mapping" }?.orderFrontRegardless()
                }
            }

            Button("Quit") {
                NSApp.terminate(nil)
            }
        }
        .padding()
        .frame(width: 220)
    }
}

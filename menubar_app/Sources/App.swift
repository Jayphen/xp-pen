import SwiftUI

@main
struct XPPenRemoteApp: App {
    @StateObject private var device = DeviceManager()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(device)
        } label: {
            Image(systemName: device.isConnected ? "dial.medium.fill" : "dial.medium")
        }
        .menuBarExtraStyle(.window)

        Window("Button Mapping", id: "mapping") {
            MappingView()
                .environmentObject(device)
                .frame(minWidth: 480, minHeight: 400)
        }
    }
}

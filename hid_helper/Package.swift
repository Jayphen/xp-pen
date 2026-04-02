// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "hid_helper",
    platforms: [.macOS(.v12)],
    targets: [
        .executableTarget(name: "hid_helper", path: "Sources"),
    ]
)

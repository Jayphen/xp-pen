// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "XPPenRemote",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "XPPenRemote",
            path: "Sources",
            exclude: ["Info.plist"],
            linkerSettings: [
                .unsafeFlags(["-Xlinker", "-sectcreate", "-Xlinker", "__TEXT", "-Xlinker", "__info_plist", "-Xlinker", "Sources/Info.plist"]),
            ]
        ),
    ]
)

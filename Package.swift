// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "DiskSpace",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .target(
            name: "DiskSpaceKit",
            path: "Sources/DiskSpaceKit"
        ),
        .executableTarget(
            name: "DiskSpace",
            dependencies: ["DiskSpaceKit"],
            path: "Sources/DiskSpace",
            exclude: ["Info.plist"],
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Sources/DiskSpace/Info.plist"
                ])
            ]
        ),
        .testTarget(
            name: "DiskSpaceTests",
            dependencies: ["DiskSpaceKit"],
            path: "Tests/DiskSpaceTests"
        )
    ]
)

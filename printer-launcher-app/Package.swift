// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "PrinterLauncher",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(
            name: "PrinterLauncher",
            targets: ["PrinterLauncher"]
        ),
    ],
    targets: [
        .executableTarget(
            name: "PrinterLauncher",
            path: "Sources/PrinterLauncher"
        ),
    ]
)

// swift-tools-version: 5.9
// Swift Package Manager — minimal, platform-dasar, tanpa dependency eksternal (init).

import PackageDescription

let package = Package(
    name: "POSiOS",
    products: [
        .executable(name: "POSiOS", targets: ["POSiOS"])
    ],
    targets: [
        .executableTarget(
            name: "POSiOS",
            path: "Sources/POSiOS"
        ),
        .testTarget(
            name: "POSiOSTests",
            dependencies: ["POSiOS"],
            path: "Tests/POSiOSTests"
        ),
    ]
)
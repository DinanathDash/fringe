// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Fringe",
    platforms: [.macOS(.v14)],
    products: [
        // A droplet is a loadable bundle, so its product is a dynamic library.
        // Do not make it static: the app already carries DroppyKit, and a
        // second copy inside the droplet gives the same type two metadata
        // records, which fails every cast between them.
        .library(name: "Fringe", type: .dynamic, targets: ["Fringe"])
    ],
    dependencies: [
        .package(url: "https://gitlab.com/droppyformac1/droppykit.git", from: "1.22.0")
    ],
    targets: [
        .target(
            name: "Fringe",
            dependencies: [.product(name: "DroppyKit", package: "droppykit")],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "FringeHarness",
            dependencies: [
                "Fringe",
                .product(name: "DroppyKitHarness", package: "droppykit")
            ],
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)

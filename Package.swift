// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "GitFlow",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "GitFlow", targets: ["GitFlow"])
    ],
    targets: [
        .executableTarget(
            name: "GitFlow",
            path: "GitFlow"
        ),
        .testTarget(
            name: "GitFlowTests",
            dependencies: ["GitFlow"],
            path: "GitFlowTests"
        )
    ]
)

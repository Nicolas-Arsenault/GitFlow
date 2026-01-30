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
    dependencies: [
        // SwiftSyntax for AST-based Swift code parsing
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "509.0.0")
    ],
    targets: [
        .executableTarget(
            name: "GitFlow",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax")
            ],
            path: "GitFlow"
        ),
        .testTarget(
            name: "GitFlowTests",
            dependencies: ["GitFlow"],
            path: "GitFlowTests"
        )
    ]
)

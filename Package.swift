// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "DeNSFW",
    platforms: [
        .iOS(.v16)
    ],
    dependencies: [
        .package(url: "https://github.com/microsoft/onnxruntime-swift-package-manager.git", from: "1.16.0")
    ],
    targets: [
        .target(
            name: "DeNSFW",
            dependencies: [
                .product(name: "onnxruntime", package: "onnxruntime-swift-package-manager")
            ]
        )
    ]
)
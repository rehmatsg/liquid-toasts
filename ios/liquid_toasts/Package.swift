// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "liquid_toasts",
    platforms: [
        .iOS("17.0")
    ],
    products: [
        .library(name: "liquid-toasts", targets: ["liquid_toasts"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "liquid_toasts",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ],
            resources: [
                // The plugin ships a privacy manifest declaring no data collection
                // and no required-reason API usage (it uses only public APIs).
                .process("PrivacyInfo.xcprivacy")
            ]
        )
    ]
)

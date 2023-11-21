// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "OnlineRadioBoxToSpotify",
    products: [
        .executable(name: "OnlineRadioBoxToSpotify", targets: ["OnlineRadioBoxToSpotify"])
    ],
    dependencies: [
        .package(url: "https://github.com/swift-server/swift-aws-lambda-runtime.git", .upToNextMajor(from: "0.3.0"))
    ],
    targets: [
        .target(
            name: "OnlineRadioBoxToSpotify",
            dependencies: [
                .product(name: "AWSLambdaRuntime", package: "swift-aws-lambda-runtime"),
            ]
        ),
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        //.executableTarget(name: "OnlineRadioBoxToSpotify"),
    ]
)

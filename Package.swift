// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "HTTPClient",
  platforms: [
    .iOS(.v13),
    .macOS(.v10_15),
    .tvOS(.v13),
    .watchOS(.v6),
  ],
  products: [
    // Products define the executables and libraries a package produces, making them visible to other packages.
    .library(
      name: "HTTPClient",
      targets: ["HTTPClient"]
    ),
    .library(
      name: "HTTPClientFoundation",
      targets: ["HTTPClientFoundation"]
    ),
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-http-types", from: "1.0.0"),
    .package(url: "https://github.com/apple/swift-collections", from: "1.0.0"),
    .package(url: "https://github.com/apple/swift-log", from: "1.0.0"),
  ],
  targets: [
    // Targets are the basic building blocks of a package, defining a module or a test suite.
    // Targets can depend on other targets in this package and products from dependencies.
    .target(
      name: "HTTPClient",
      dependencies: [
        .product(name: "HTTPTypes", package: "swift-http-types"),
        .product(name: "Logging", package: "swift-log"),
      ]
    ),
    .target(
      name: "HTTPClientFoundation",
      dependencies: [
        .product(name: "DequeModule", package: "swift-collections"),
        .product(name: "HTTPTypesFoundation", package: "swift-http-types"),
        "HTTPClient",
      ]
    ),
    .testTarget(
      name: "HTTPClientTests",
      dependencies: ["HTTPClient", "HTTPClientFoundation"]
    ),
  ]
)

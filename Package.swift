// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "http-client",
  platforms: [.macOS(.v12), .iOS(.v15), .watchOS(.v8), .tvOS(.v15)],
  products: [
    // Products define the executables and libraries a package produces, making them visible to other packages.
    .library(
      name: "HTTPClient",
      targets: ["HTTPClient"])
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-http-types", from: "0.1.1")
  ],
  targets: [
    // Targets are the basic building blocks of a package, defining a module or a test suite.
    // Targets can depend on other targets in this package and products from dependencies.
    .target(
      name: "HTTPClient",
      dependencies: [
        .product(name: "HTTPTypes", package: "swift-http-types"),
        .product(name: "HTTPTypesFoundation", package: "swift-http-types"),
      ]
    ),
    .testTarget(
      name: "HTTPClientTests",
      dependencies: ["HTTPClient"]
    ),
  ]
)

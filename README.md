# `swift-http-client`

A Swift HTTP client built upon [`SwiftOpenAPIRuntime`](https://github.com/apple/swift-openapi-runtime) and [`OpenAPIURLSession`](https://github.com/apple/swift-openapi-urlsession) implementations. This library provides the base types from those libraries, excluding the code generation specific code.

If you want to leverage the benefits of those Apple libraries without using code generation, this is the library for you.

## Installation

Add the following to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/grdsdev/swift-http-client", from: "0.1.0")
],
targets: [
    .target(
        name: "YourTarget",
        dependencies: [
            .product(name: "HTTPClient", package: "swift-http-client")
        ]
    )
]
```

## Usage

```swift
import HTTPClient

let client = Client(
    serverURL: URL(string: "https://api.example.com")!,
    transport: URLSessionTransport(),
    middlewares: [
        LoggingMiddleware(logger: Logger(label: "HTTPClient")),
        // Add other middlewares here...
    ]
)

let request = HTTPRequest(
    method: .get,
    url: URL(string: "https://api.example.com/users")!,
)

let (response, body) = try await client.send(request)
```

### Multipart Form Data

The library provides built-in support for `multipart/form-data` requests, making it easy to upload files and form data:

```swift
// Using closure builder pattern
let request = HTTPRequest(method: .post, url: URL(string: "/upload")!)

let (response, body) = try await client.send(
    multipartFormData: { formData in
        // Add text fields
        formData.append(
            "John Doe".data(using: .utf8)!,
            withName: "username"
        )
        
        // Add files
        let fileURL = URL(fileURLWithPath: "/path/to/document.pdf")
        formData.append(fileURL, withName: "document")
        
        // Add data with custom filename and MIME type
        let imageData = ... // Your image data
        formData.append(
            imageData,
            withName: "avatar",
            fileName: "profile.jpg",
            mimeType: "image/jpeg"
        )
    },
    with: request
)
```

The library automatically handles:
- Setting the correct `Content-Type` header with boundary
- Memory-efficient encoding (data < 10 MB is encoded in memory, larger data is streamed from disk)
- Automatic MIME type detection for file uploads

## Features

- **Transport Abstraction**: Pluggable transport layer with URLSession implementation included
- **Middleware Support**: Interceptors for logging, authentication, metrics, and custom request/response processing
- **Multipart Form Data**: Built-in support for file uploads with automatic memory management
- **Platform Support**: Works on iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, and Linux
- **Swift Concurrency**: Built with async/await and Sendable support
- **Structured Error Handling**: Comprehensive error types with request/response context
- **Streaming Support**: Platform-adaptive streaming for large request/response bodies

## Architecture

The library provides a simple but powerful architecture:

- **Client**: Main interface that orchestrates requests through transport and middleware layers
- **ClientTransport**: Protocol for abstracting HTTP operations (URLSession implementation provided)
- **ClientMiddleware**: Protocol for request/response interception (logging middleware included)
- **HTTPBody**: Streaming-capable request and response body handling

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

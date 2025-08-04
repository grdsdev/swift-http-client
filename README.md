# `swift-http-client`

A Swift HTTP client built upon [`SwiftOpenAPIRuntime`](https://github.com/apple/swift-openapi-runtime) and [`OpenAPIURLSession`](https://github.com/apple/swift-openapi-urlsession) implementations. This library provides the base types from those libraries, excluding the code generation specific code.

If you want to leverage the benefits of those Apple libraries without using code generation, this is the library for you.

## Usage

```swift

import HTTPClient
import HTTPClientFoundation // for the Foundation-based implementation

let client = Client(
    baseURL: URL(string: "https://api.example.com")!,
    transport: URLSessionTransport(),
    middlewares: [
        LoggingMiddleware(),
        /// ...
    ]
)

let request = HTTPRequest(
    method: .get,
    url: URL(string: "https://api.example.com/users")!,
)

let (response, body) = try await client.send(request)
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
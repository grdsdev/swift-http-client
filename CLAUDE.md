# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## About This Project

This is a Swift HTTP client library built upon Apple's SwiftOpenAPIRuntime and OpenAPIURLSession implementations. It extracts the base types from those libraries without the code generation components, allowing developers to use the benefits of Apple's HTTP libraries without OpenAPI code generation.

## Architecture Overview

The library is structured as a single module with organized subdirectories:

### HTTPClient Module

#### Core Interface (`Interface/`)
- **Client.swift**: Main HTTP client that orchestrates requests through transport and middleware layers
- **ClientTransport**: Protocol that abstracts HTTP operations from underlying libraries
- **ClientMiddleware**: Protocol for request/response interception (auth, logging, metrics)
- **HTTPBody**: Core body type with streaming support and progress tracking (`HTTPBody+Progress.swift`)
- **MultipartFormData**: Built-in support for multipart/form-data requests with automatic encoding
- **CurrencyTypes**: Common types used across the library

#### Foundation Transport (`HTTPClientFoundation/`)
- **URLSessionTransport**: Foundation-based implementation of `ClientTransport` using URLSession
- **Bidirectional Streaming**: Platform-specific streaming support for request/response bodies
- **Buffered Streams**: Custom buffered streaming implementation with lock management for platforms without native streaming

#### Error Handling (`Errors/`)
- Structured error types with `ClientError` and `RuntimeError`
- Errors include full context (request, response, baseURL)

#### Middlewares (`Middlewares/`)
- **LoggingMiddleware**: Structured logging integration via swift-log

## Key Design Patterns

1. **Middleware Chain**: Requests flow through middleware stack in order, responses in reverse order
2. **Transport Abstraction**: Single transport required per client, abstracts underlying HTTP library
3. **Platform Adaptation**: Conditional compilation for Darwin vs Linux Foundation differences
4. **Error Wrapping**: All errors wrapped in `ClientError` with context (request, response, baseURL)

## Platform Support

- iOS 16.0+
- macOS 13.0+
- macCatalyst 16.0+
- watchOS 9.0+
- tvOS 16.0+
- Swift 6.0+

## Development Commands

### Building
```bash
swift build
```

### Running Tests
```bash
swift test
```

### Running Specific Tests
```bash
swift test --filter HTTPClientTests
```

### CI/CD
The project uses GitHub Actions for continuous integration:
- **macOS**: Tests on Xcode 16.4 and 26.0 in both debug and release configurations
- **Linux**: Builds on Swift 6.2
- **Integration Tests**: Uses go-httpbin (httpbingo.org) for real HTTP testing

## Dependencies

- **HTTPTypes** (Apple): Core HTTP request/response types
- **HTTPTypesFoundation** (Apple): Foundation integration for HTTPTypes
- **swift-log** (Apple): Structured logging via `LoggingMiddleware`
- **swift-collections** (Apple): `DequeModule` for buffered streaming

## Testing Framework

Uses Apple's Swift Testing framework (not XCTest). Test files use:
- `@Test` attribute for test functions
- `#expect()` for assertions
- `@testable import` for internal access

## Key Features

### Multipart Form Data
Built-in support for `multipart/form-data` requests with:
- Memory-efficient encoding (< 10 MB in memory, larger files streamed from disk)
- Automatic MIME type detection for file uploads
- Convenient builder API via `Client.send(multipartFormData:with:)`

### HTTPBody Progress Tracking
Monitor upload/download progress through `HTTPBody+Progress.swift` for:
- Real-time progress updates during streaming operations
- Integration with progress reporting UIs

### Bidirectional Streaming
Platform-optimized streaming support:
- Native streaming on Darwin platforms (iOS, macOS, etc.)
- Buffered streaming fallback for Linux/other platforms
- Lock-based synchronization for thread safety

## Code Conventions

- **License**: Project uses MIT license, though source files retain Apache 2.0 headers from upstream Apple code
- Platform-specific imports with `#if canImport(Darwin)` blocks
- `@preconcurrency` imports for Linux Foundation types
- Sendable conformance throughout for Swift concurrency safety
- Single module architecture with organized subdirectories
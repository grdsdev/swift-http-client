# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## About This Project

This is a Swift HTTP client library built upon Apple's SwiftOpenAPIRuntime and OpenAPIURLSession implementations. It extracts the base types from those libraries without the code generation components, allowing developers to use the benefits of Apple's HTTP libraries without OpenAPI code generation.

## Architecture Overview

The library is structured into two main modules:

### HTTPClient Module
- **Core Interface**: `Client.swift` - Main HTTP client that orchestrates requests through transport and middleware layers
- **Transport Layer**: `ClientTransport` protocol abstracts HTTP operations from underlying libraries
- **Middleware Layer**: `ClientMiddleware` protocol for request/response interception (auth, logging, metrics)
- **Error Handling**: Structured error types in `Errors/` with `ClientError` and `RuntimeError`
- **HTTP Types**: Built on Apple's `HTTPTypes` package for request/response modeling

### HTTPClientFoundation Module  
- **URLSessionTransport**: Foundation-based implementation of `ClientTransport` using URLSession
- **Streaming Support**: Platform-dependent streaming vs buffered request handling
- **Buffered Streams**: Custom buffered streaming implementation with lock management

## Key Design Patterns

1. **Middleware Chain**: Requests flow through middleware stack in order, responses in reverse order
2. **Transport Abstraction**: Single transport required per client, abstracts underlying HTTP library
3. **Platform Adaptation**: Conditional compilation for Darwin vs Linux Foundation differences
4. **Error Wrapping**: All errors wrapped in `ClientError` with context (request, response, baseURL)

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

## Dependencies

- **HTTPTypes** (Apple): Core HTTP request/response types
- **swift-log** (Apple): Structured logging via `LoggingMiddleware`  
- **swift-collections** (Apple): `DequeModule` for buffered streaming

## Testing Framework

Uses Apple's Swift Testing framework (not XCTest). Test files use:
- `@Test` attribute for test functions
- `#expect()` for assertions
- `@testable import` for internal access

## Code Conventions

- Apache 2.0 license headers on all source files
- Platform-specific imports with `#if canImport(Darwin)` blocks
- `@preconcurrency` imports for Linux Foundation types
- Sendable conformance throughout for Swift concurrency safety
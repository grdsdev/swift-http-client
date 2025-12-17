import Foundation
import HTTPTypes
import Testing

@testable import HTTPClient

@Suite
struct ErrorTests {

  // MARK: - ClientError Tests

  @Test func clientErrorInitialization() {
    let serverURL = URL(string: "https://api.example.com")!
    let request = HTTPRequest(method: .get, url: serverURL.appending(path: "test"))
    let requestBody = HTTPBody("request data")

    let response = HTTPResponse(status: .badRequest)
    let responseBody = HTTPBody("error data")

    struct TestError: Error {}
    let underlyingError = TestError()

    let clientError = ClientError(
      request: request,
      requestBody: requestBody,
      baseURL: serverURL,
      response: response,
      responseBody: responseBody,
      causeDescription: "Test error",
      underlyingError: underlyingError
    )

    #expect(clientError.request?.method == .get)
    #expect(clientError.requestBody != nil)
    #expect(clientError.baseURL == serverURL)
    #expect(clientError.response?.status == .badRequest)
    #expect(clientError.responseBody != nil)
    #expect(clientError.causeDescription == "Test error")
    #expect(clientError.underlyingError is TestError)
  }

  @Test func clientErrorWithNilFields() {
    struct TestError: Error {}

    let clientError = ClientError(
      causeDescription: "Early error",
      underlyingError: TestError()
    )

    #expect(clientError.request == nil)
    #expect(clientError.requestBody == nil)
    #expect(clientError.baseURL == nil)
    #expect(clientError.response == nil)
    #expect(clientError.responseBody == nil)
    #expect(clientError.causeDescription == "Early error")
  }

  @Test func clientErrorDescription() {
    let serverURL = URL(string: "https://api.example.com")!
    let request = HTTPRequest(method: .post, url: serverURL.appending(path: "users"))

    struct TestError: Error {}

    let clientError = ClientError(
      request: request,
      baseURL: serverURL,
      causeDescription: "Network failure",
      underlyingError: TestError()
    )

    let description = clientError.description
    #expect(description.contains("Network failure"))
    #expect(description.contains("POST"))
  }

  @Test func clientErrorLocalizedDescription() {
    struct TestError: Error, LocalizedError {
      var errorDescription: String? { "Underlying test error" }
    }

    let clientError = ClientError(
      causeDescription: "Transport failed",
      underlyingError: TestError()
    )

    let localizedDesc = clientError.errorDescription
    #expect(localizedDesc?.contains("Transport failed") == true)
    #expect(localizedDesc?.contains("Underlying test error") == true)
  }

  // MARK: - RuntimeError Tests

  @Test func runtimeErrorTransportFailed() {
    struct TransportError: Error {}
    let error = RuntimeError.transportFailed(TransportError())

    #expect(error.prettyDescription == "Transport threw an error.")
    #expect(error.underlyingError is TransportError)
  }

  @Test func runtimeErrorMiddlewareFailed() {
    struct MiddlewareError: Error {}
    struct TestMiddleware: ClientMiddleware {
      func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        next: (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
      ) async throws -> (HTTPResponse, HTTPBody?) {
        try await next(request, body, baseURL)
      }
    }

    let error = RuntimeError.middlewareFailed(
      middlewareType: TestMiddleware.self,
      MiddlewareError()
    )

    #expect(error.prettyDescription.contains("Middleware"))
    #expect(error.prettyDescription.contains("TestMiddleware"))
    #expect(error.underlyingError is MiddlewareError)
  }

  @Test func runtimeErrorDescription() {
    struct TestError: Error {}
    let error = RuntimeError.transportFailed(TestError())

    let description = error.description
    #expect(description == "Transport threw an error.")
  }

  @Test func runtimeErrorLocalizedDescription() {
    struct TestError: Error {}
    let error = RuntimeError.transportFailed(TestError())

    let localizedDesc = error.errorDescription
    #expect(localizedDesc == "Transport threw an error.")
  }

  @Test func runtimeErrorHTTPStatus() {
    struct TestError: Error {}

    let transportError = RuntimeError.transportFailed(TestError())
    #expect(transportError.httpStatus == .internalServerError)

    struct DummyMiddleware: ClientMiddleware {
      func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        next: (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
      ) async throws -> (HTTPResponse, HTTPBody?) {
        try await next(request, body, baseURL)
      }
    }

    let middlewareError = RuntimeError.middlewareFailed(
      middlewareType: DummyMiddleware.self,
      TestError()
    )
    #expect(middlewareError.httpStatus == .internalServerError)
  }

  @Test func runtimeErrorHTTPHeaderFields() {
    struct TestError: Error {}
    let error = RuntimeError.transportFailed(TestError())

    let headers = error.httpHeaderFields
    #expect(headers.isEmpty)
  }

  @Test func runtimeErrorHTTPBody() {
    struct TestError: Error {}
    let error = RuntimeError.transportFailed(TestError())

    #expect(error.httpBody == nil)
  }

  // MARK: - Error Propagation Tests

  @Test func clientWrapsTransportError() async throws {
    struct TransportError: Error {}

    struct FailingTransport: ClientTransport {
      func send(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL
      ) async throws -> (HTTPResponse, HTTPBody?) {
        throw TransportError()
      }
    }

    let serverURL = URL(string: "https://api.example.com")!
    let client = Client(serverURL: serverURL, transport: FailingTransport())

    let request = HTTPRequest(method: .get, url: serverURL.appending(path: "test"))

    var caughtClientError: ClientError?
    do {
      _ = try await client.send(request)
    } catch let error as ClientError {
      caughtClientError = error
    }

    let error = try #require(caughtClientError)
    #expect(error.causeDescription == "Transport threw an error.")
    #expect(error.underlyingError is TransportError)
    #expect(error.request?.method == .get)
    #expect(error.baseURL == serverURL)
  }

  @Test func clientWrapsMiddlewareError() async throws {
    struct MiddlewareError: Error {}

    struct FailingMiddleware: ClientMiddleware {
      func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        next: (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
      ) async throws -> (HTTPResponse, HTTPBody?) {
        throw MiddlewareError()
      }
    }

    struct MockTransport: ClientTransport {
      func send(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL
      ) async throws -> (HTTPResponse, HTTPBody?) {
        (HTTPResponse(status: .ok), nil)
      }
    }

    let serverURL = URL(string: "https://api.example.com")!
    let client = Client(
      serverURL: serverURL,
      transport: MockTransport(),
      middlewares: [FailingMiddleware()]
    )

    let request = HTTPRequest(method: .get, url: serverURL.appending(path: "test"))

    var caughtClientError: ClientError?
    do {
      _ = try await client.send(request)
    } catch let error as ClientError {
      caughtClientError = error
    }

    let error = try #require(caughtClientError)
    #expect(error.causeDescription.contains("Middleware"))
    #expect(error.causeDescription.contains("FailingMiddleware"))
    #expect(error.underlyingError is MiddlewareError)
  }

  @Test func clientErrorPreservesExistingContext() async throws {
    // Test that if a ClientError is thrown, it preserves existing context

    struct ContextPreservingMiddleware: ClientMiddleware {
      func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        next: (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
      ) async throws -> (HTTPResponse, HTTPBody?) {
        // Throw a pre-constructed ClientError
        let existingError = ClientError(
          request: request,
          baseURL: URL(string: "https://original.com")!,
          causeDescription: "Original error",
          underlyingError: NSError(domain: "test", code: 1)
        )
        throw existingError
      }
    }

    struct MockTransport: ClientTransport {
      func send(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL
      ) async throws -> (HTTPResponse, HTTPBody?) {
        (HTTPResponse(status: .ok), nil)
      }
    }

    let serverURL = URL(string: "https://api.example.com")!
    let client = Client(
      serverURL: serverURL,
      transport: MockTransport(),
      middlewares: [ContextPreservingMiddleware()]
    )

    let request = HTTPRequest(method: .get, url: serverURL.appending(path: "test"))

    var caughtClientError: ClientError?
    do {
      _ = try await client.send(request)
    } catch let error as ClientError {
      caughtClientError = error
    }

    let error = try #require(caughtClientError)
    // The original baseURL should be preserved
    #expect(error.baseURL?.absoluteString == "https://original.com")
    #expect(error.causeDescription.contains("Original error"))
  }

  // MARK: - Pretty Description Tests

  @Test func clientErrorPrettyDescription() {
    let serverURL = URL(string: "https://api.example.com")!
    var request = HTTPRequest(method: .get, url: serverURL.appending(path: "api/users"))
    request.headerFields[.accept] = "application/json"

    let response = HTTPResponse(status: .notFound)

    struct PrettyError: Error, PrettyStringConvertible {
      var prettyDescription: String { "Pretty error description" }
    }

    let clientError = ClientError(
      request: request,
      baseURL: serverURL,
      response: response,
      causeDescription: "Resource not found",
      underlyingError: PrettyError()
    )

    let description = clientError.description
    #expect(description.contains("Resource not found"))
    #expect(description.contains("Pretty error description"))
    #expect(description.contains("404"))
  }

  @Test func runtimeErrorWithPrettyUnderlyingError() {
    struct PrettyError: Error, PrettyStringConvertible {
      var prettyDescription: String { "Detailed error info" }
    }

    let error = RuntimeError.transportFailed(PrettyError())

    // The underlying error should be extractable
    let underlying = error.underlyingError as? PrettyError
    #expect(underlying?.prettyDescription == "Detailed error info")
  }

  // MARK: - Error Context Tests

  @Test func clientErrorWithRequestBodyContext() async throws {
    struct TestError: Error {}

    struct FailingTransport: ClientTransport {
      func send(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL
      ) async throws -> (HTTPResponse, HTTPBody?) {
        throw TestError()
      }
    }

    let serverURL = URL(string: "https://api.example.com")!
    let client = Client(serverURL: serverURL, transport: FailingTransport())

    let request = HTTPRequest(method: .post, url: serverURL.appending(path: "test"))
    let requestBody = HTTPBody("Important request data")

    var caughtClientError: ClientError?
    do {
      _ = try await client.send(request, body: requestBody)
    } catch let error as ClientError {
      caughtClientError = error
    }

    let error = try #require(caughtClientError)
    #expect(error.requestBody != nil)
    #expect(error.request?.method == .post)
  }

  @Test func clientErrorWithResponseContext() async throws {
    // This test would require a transport that returns a response before failing
    // In practice, this is less common but the API supports it

    struct TestError: Error {}

    let serverURL = URL(string: "https://api.example.com")!
    let clientError = ClientError(
      request: HTTPRequest(method: .get, url: serverURL.appending(path: "test")),
      baseURL: serverURL,
      response: HTTPResponse(status: .badRequest),
      responseBody: HTTPBody("Error details"),
      causeDescription: "Bad request",
      underlyingError: TestError()
    )

    #expect(clientError.response?.status == .badRequest)
    #expect(clientError.responseBody != nil)
  }
}

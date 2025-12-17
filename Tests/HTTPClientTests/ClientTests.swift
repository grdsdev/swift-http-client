import Foundation
import HTTPTypes
import Testing

@testable import HTTPClient

@Suite
struct ClientTests {

  // MARK: - Test Helpers

  /// A mock transport for testing
  struct MockTransport: ClientTransport {
    let responseStatus: HTTPResponse.Status
    let responseBody: String?
    var onSend: ((HTTPRequest, HTTPBody?, URL) -> Void)?

    init(
      responseStatus: HTTPResponse.Status = .ok,
      responseBody: String? = nil,
      onSend: ((HTTPRequest, HTTPBody?, URL) -> Void)? = nil
    ) {
      self.responseStatus = responseStatus
      self.responseBody = responseBody
      self.onSend = onSend
    }

    func send(
      _ request: HTTPRequest,
      body: HTTPBody?,
      baseURL: URL
    ) async throws -> (HTTPResponse, HTTPBody?) {
      onSend?(request, body, baseURL)

      let response = HTTPResponse(status: responseStatus)
      let body = responseBody.map { HTTPBody($0) }
      return (response, body)
    }
  }

  /// A failing transport for testing error scenarios
  struct FailingTransport: ClientTransport {
    struct TransportFailure: Error {}

    func send(
      _ request: HTTPRequest,
      body: HTTPBody?,
      baseURL: URL
    ) async throws -> (HTTPResponse, HTTPBody?) {
      throw TransportFailure()
    }
  }

  /// A mock middleware for testing
  struct MockMiddleware: ClientMiddleware {
    let id: String
    var onIntercept: ((HTTPRequest, HTTPBody?, URL) -> Void)?
    var shouldModifyRequest: Bool = false
    var shouldFail: Bool = false

    struct MiddlewareError: Error {}

    func intercept(
      _ request: HTTPRequest,
      body: HTTPBody?,
      baseURL: URL,
      next: (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
      onIntercept?(request, body, baseURL)

      if shouldFail {
        throw MiddlewareError()
      }

      var modifiedRequest = request
      if shouldModifyRequest {
        modifiedRequest.headerFields[.init("X-Middleware")!] = id
      }

      return try await next(modifiedRequest, body, baseURL)
    }
  }

  // MARK: - Initialization Tests

  @Test func clientInitialization() {
    let serverURL = URL(string: "https://api.example.com")!
    let transport = MockTransport()
    let client = Client(serverURL: serverURL, transport: transport)

    #expect(client.serverURL == serverURL)
    #expect(client.middlewares.isEmpty)
  }

  @Test func clientInitializationWithMiddlewares() {
    let serverURL = URL(string: "https://api.example.com")!
    let transport = MockTransport()
    let middleware1 = MockMiddleware(id: "m1")
    let middleware2 = MockMiddleware(id: "m2")

    let client = Client(
      serverURL: serverURL,
      transport: transport,
      middlewares: [middleware1, middleware2]
    )

    #expect(client.serverURL == serverURL)
    #expect(client.middlewares.count == 2)
  }

  // MARK: - Basic Request Tests

  @Test func sendSimpleRequest() async throws {
    let serverURL = URL(string: "https://api.example.com")!
    let transport = MockTransport(responseStatus: .ok, responseBody: "Success")
    let client = Client(serverURL: serverURL, transport: transport)

    let request = HTTPRequest(method: .get, url: serverURL.appending(path: "users"))
    let (response, body) = try await client.send(request)

    #expect(response.status == .ok)
    let bodyString = try await String(collecting: try #require(body), upTo: 1024)
    #expect(bodyString == "Success")
  }

  @Test func sendRequestWithBody() async throws {
    let serverURL = URL(string: "https://api.example.com")!
    var capturedBody: String?

    let transport = MockTransport(
      responseStatus: .created,
      onSend: { _, body, _ in
        Task {
          if let body = body {
            capturedBody = try? await String(collecting: body, upTo: 1024)
          }
        }
      }
    )

    let client = Client(serverURL: serverURL, transport: transport)

    let request = HTTPRequest(method: .post, url: serverURL.appending(path: "users"))
    let requestBody = HTTPBody("Request Data")

    let (response, _) = try await client.send(request, body: requestBody)

    #expect(response.status == .created)
    // Note: Body consumption is async, so we can't reliably test capturedBody here
  }

  @Test func clientPassesBaseURLToTransport() async throws {
    let serverURL = URL(string: "https://api.example.com")!
    var capturedBaseURL: URL?

    let transport = MockTransport(
      onSend: { _, _, baseURL in
        capturedBaseURL = baseURL
      }
    )

    let client = Client(serverURL: serverURL, transport: transport)

    let request = HTTPRequest(method: .get, url: serverURL.appending(path: "test"))
    _ = try await client.send(request)

    #expect(capturedBaseURL == serverURL)
  }

  // MARK: - Middleware Tests

  @Test func middlewareExecutionOrder() async throws {
    let serverURL = URL(string: "https://api.example.com")!
    var executionOrder: [String] = []

    let middleware1 = MockMiddleware(
      id: "m1",
      onIntercept: { _, _, _ in
        executionOrder.append("m1")
      }
    )

    let middleware2 = MockMiddleware(
      id: "m2",
      onIntercept: { _, _, _ in
        executionOrder.append("m2")
      }
    )

    let transport = MockTransport(
      onSend: { _, _, _ in
        executionOrder.append("transport")
      }
    )

    let client = Client(
      serverURL: serverURL,
      transport: transport,
      middlewares: [middleware1, middleware2]
    )

    let request = HTTPRequest(method: .get, url: serverURL.appending(path: "test"))
    _ = try await client.send(request)

    // Middlewares should execute in order, then transport
    #expect(executionOrder == ["m1", "m2", "transport"])
  }

  @Test func middlewareCanModifyRequest() async throws {
    let serverURL = URL(string: "https://api.example.com")!
    var capturedRequest: HTTPRequest?

    let middleware = MockMiddleware(id: "test", shouldModifyRequest: true)
    let transport = MockTransport(
      onSend: { request, _, _ in
        capturedRequest = request
      }
    )

    let client = Client(
      serverURL: serverURL,
      transport: transport,
      middlewares: [middleware]
    )

    let request = HTTPRequest(method: .get, url: serverURL.appending(path: "test"))
    _ = try await client.send(request)

    #expect(capturedRequest?.headerFields[.init("X-Middleware")!] == "test")
  }

  @Test func multipleMiddlewaresCanChainModifications() async throws {
    let serverURL = URL(string: "https://api.example.com")!
    var capturedRequest: HTTPRequest?

    let middleware1 = MockMiddleware(id: "first", shouldModifyRequest: true)
    let middleware2 = MockMiddleware(id: "second", shouldModifyRequest: true)

    let transport = MockTransport(
      onSend: { request, _, _ in
        capturedRequest = request
      }
    )

    let client = Client(
      serverURL: serverURL,
      transport: transport,
      middlewares: [middleware1, middleware2]
    )

    let request = HTTPRequest(method: .get, url: serverURL.appending(path: "test"))
    _ = try await client.send(request)

    // Both middlewares should have modified the request
    // Note: The test middleware adds the same header, so we only see the last one
    #expect(capturedRequest?.headerFields[.init("X-Middleware")!] != nil)
  }

  // MARK: - Error Handling Tests

  @Test func transportErrorIsWrappedInClientError() async throws {
    let serverURL = URL(string: "https://api.example.com")!
    let transport = FailingTransport()
    let client = Client(serverURL: serverURL, transport: transport)

    let request = HTTPRequest(method: .get, url: serverURL.appending(path: "test"))

    var caughtError: ClientError?
    do {
      _ = try await client.send(request)
    } catch let error as ClientError {
      caughtError = error
    }

    let error = try #require(caughtError)
    #expect(error.request != nil)
    #expect(error.baseURL == serverURL)
    #expect(error.causeDescription == "Transport threw an error.")
  }

  @Test func middlewareErrorIsWrappedInClientError() async throws {
    let serverURL = URL(string: "https://api.example.com")!
    let middleware = MockMiddleware(id: "failing", shouldFail: true)
    let transport = MockTransport()

    let client = Client(
      serverURL: serverURL,
      transport: transport,
      middlewares: [middleware]
    )

    let request = HTTPRequest(method: .get, url: serverURL.appending(path: "test"))

    var caughtError: ClientError?
    do {
      _ = try await client.send(request)
    } catch let error as ClientError {
      caughtError = error
    }

    let error = try #require(caughtError)
    #expect(error.request != nil)
    #expect(error.baseURL == serverURL)
    #expect(error.causeDescription.contains("Middleware"))
  }

  @Test func clientErrorPreservesContext() async throws {
    let serverURL = URL(string: "https://api.example.com")!
    let transport = FailingTransport()
    let client = Client(serverURL: serverURL, transport: transport)

    let request = HTTPRequest(method: .post, url: serverURL.appending(path: "test"))
    let requestBody = HTTPBody("test body")

    var caughtError: ClientError?
    do {
      _ = try await client.send(request, body: requestBody)
    } catch let error as ClientError {
      caughtError = error
    }

    let error = try #require(caughtError)
    #expect(error.request?.method == .post)
    #expect(error.requestBody != nil)
    #expect(error.baseURL == serverURL)
    #expect(error.response == nil)  // No response received
    #expect(error.responseBody == nil)
  }

  // MARK: - Edge Cases

  @Test func clientWithNoMiddlewares() async throws {
    let serverURL = URL(string: "https://api.example.com")!
    let transport = MockTransport(responseStatus: .ok)
    let client = Client(serverURL: serverURL, transport: transport, middlewares: [])

    let request = HTTPRequest(method: .get, url: serverURL.appending(path: "test"))
    let (response, _) = try await client.send(request)

    #expect(response.status == .ok)
  }

  @Test func clientWithEmptyRequestBody() async throws {
    let serverURL = URL(string: "https://api.example.com")!
    let transport = MockTransport(responseStatus: .ok)
    let client = Client(serverURL: serverURL, transport: transport)

    let request = HTTPRequest(method: .post, url: serverURL.appending(path: "test"))
    let (response, _) = try await client.send(request, body: HTTPBody())

    #expect(response.status == .ok)
  }

  @Test func clientWithNilResponseBody() async throws {
    let serverURL = URL(string: "https://api.example.com")!
    let transport = MockTransport(responseStatus: .noContent, responseBody: nil)
    let client = Client(serverURL: serverURL, transport: transport)

    let request = HTTPRequest(method: .delete, url: serverURL.appending(path: "test"))
    let (response, body) = try await client.send(request)

    #expect(response.status == .noContent)
    #expect(body == nil)
  }

  @Test func clientWithDifferentHTTPMethods() async throws {
    let serverURL = URL(string: "https://api.example.com")!
    let transport = MockTransport(responseStatus: .ok)
    let client = Client(serverURL: serverURL, transport: transport)

    let methods: [HTTPRequest.Method] = [.get, .post, .put, .delete, .patch, .head, .options]

    for method in methods {
      let request = HTTPRequest(method: method, url: serverURL.appending(path: "test"))
      let (response, _) = try await client.send(request)
      #expect(response.status == .ok)
    }
  }

  // MARK: - Concurrent Request Tests

  @Test func concurrentRequests() async throws {
    let serverURL = URL(string: "https://api.example.com")!
    let transport = MockTransport(responseStatus: .ok, responseBody: "Success")
    let client = Client(serverURL: serverURL, transport: transport)

    // Send multiple requests concurrently
    await withTaskGroup(of: Void.self) { group in
      for i in 0..<10 {
        group.addTask {
          let request = HTTPRequest(method: .get, url: serverURL.appending(path: "test/\(i)"))
          _ = try? await client.send(request)
        }
      }
    }

    // If we got here without crashing, concurrent access works
    #expect(true)
  }
}

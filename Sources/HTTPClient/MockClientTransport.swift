import Foundation

/// An in-memory, deterministic `ClientTransport` implementation for tests.
///
/// `MockClientTransport` lets you register request matchers ("mocks") and return a pre-canned
/// response when a request matches. It's designed for unit tests and integration tests where you
/// want to avoid real networking while still exercising your client's request/response handling.
///
/// The transport is implemented as an `actor`, so registering mocks and sending requests is safe
/// under concurrency.
///
/// ## Matching behavior
/// - Mocks are evaluated **in registration order** (first match wins).
/// - The first mock whose matcher returns `true` will be used to produce the response.
/// - If no mock matches, `send(_:body:baseURL:)` throws `MockNotFoundError`.
///
/// ## Examples
///
/// Register a mock that matches by method + path:
///
/// ```swift
/// import Foundation
/// import HTTPClient
///
/// let transport = MockClientTransport()
///   .on({ request, _, _ in
///     request.method == .get && request.path == "/health"
///   }, return: {
///     (HTTPResponse(status: .ok), nil)
///   })
/// ```
///
/// Register multiple mocks where **order matters**:
///
/// ```swift
/// import Foundation
/// import HTTPClient
///
/// let transport = MockClientTransport()
///   .on({ $0.path == "/users/me" }, return: {
///     (HTTPResponse(status: .unauthorized), nil)
///   })
///   .on({ $0.path == "/users/me" }, return: {
///     // Never reached because the first mock already matches.
///     (HTTPResponse(status: .ok), nil)
///   })
/// ```
///
/// Match using the full signature (request + body + base URL):
///
/// ```swift
/// import Foundation
/// import HTTPClient
///
/// let transport = MockClientTransport()
///   .on({ request, body, baseURL in
///     baseURL.host == "api.example.com" &&
///     request.method == .post &&
///     request.path == "/upload" &&
///     body != nil
///   }, return: {
///     (HTTPResponse(status: .created), nil)
///   })
/// ```
public actor MockClientTransport: ClientTransport {

  /// A predicate used to determine whether a given request should be handled by a mock.
  ///
  /// - Parameters:
  ///   - request: The outgoing `HTTPRequest`.
  ///   - body: The outgoing request body (if any).
  ///   - baseURL: The base URL the client is configured with for this request.
  /// - Returns: `true` if the mock should handle the request; otherwise `false`.
  public typealias RequestFilter = (HTTPRequest, HTTPBody?, URL) -> Bool

  struct Mock {
    let handleRequest: RequestFilter
    let returnResponse: () async throws -> (HTTPResponse, HTTPBody?)
  }

  /// Creates an empty mock transport with no registered mocks.
  ///
  /// You typically register mocks by chaining calls to `on(_:return:)`.
  public init() {}

  var mocks: [Mock] = []

  /// Sends a request through the mock transport.
  ///
  /// This method searches the registered mocks in order and returns the first response whose
  /// request filter matches the outgoing request.
  ///
  /// - Parameters:
  ///   - request: The outgoing `HTTPRequest`.
  ///   - body: The outgoing request body (if any).
  ///   - baseURL: The base URL the client is configured with for this request.
  /// - Returns: A tuple of `(HTTPResponse, HTTPBody?)` produced by the matched mock.
  /// - Throws:
  ///   - Any error thrown by the matched mock's response closure.
  ///   - `MockNotFoundError` if no registered mock matches the request.
  public func send(
    _ request: HTTPRequest,
    body: HTTPBody?,
    baseURL: URL
  ) async throws -> (HTTPResponse, HTTPBody?) {
    for mock in mocks {
      if mock.handleRequest(request, body, baseURL) {
        return try await mock.returnResponse()
      }
    }
    throw MockNotFoundError(request: request, body: body, baseURL: baseURL)
  }

  /// Registers a mock using the full `(HTTPRequest, HTTPBody?, URL)` matching signature.
  ///
  /// Mocks are evaluated **in the order they are registered**. The first mock whose matcher returns
  /// `true` will be used to generate the response.
  ///
  /// - Parameters:
  ///   - request: A predicate that decides whether this mock handles an outgoing request.
  ///   - response: An async closure that produces the response to return when matched.
  /// - Returns: `self`, enabling fluent chaining.
  @discardableResult
  public func on(
    _ request: @escaping RequestFilter,
    return response: @escaping () async throws -> (HTTPResponse, HTTPBody?)
  ) -> Self {
    let mock = Mock(handleRequest: request, returnResponse: response)
    mocks.append(mock)
    return self
  }

  /// Registers a mock using only the `HTTPRequest` for matching.
  ///
  /// This is a convenience overload for cases where matching doesn't depend on the body or base
  /// URL. Under the hood it forwards to `on(_:return:)`.
  ///
  /// - Parameters:
  ///   - request: A predicate that decides whether this mock handles an outgoing request.
  ///   - response: An async closure that produces the response to return when matched.
  /// - Returns: `self`, enabling fluent chaining.
  @discardableResult
  public func on(
    _ request: @escaping (HTTPRequest) -> Bool,
    return response: @escaping () async throws -> (HTTPResponse, HTTPBody?)
  ) -> Self {
    self.on { r, _, _ in
      request(r)
    } return: {
      try await response()
    }

  }

  /// Thrown when `send(_:body:baseURL:)` can't find a matching registered mock.
  ///
  /// The error carries the original request, body, and base URL to help tests diagnose why the
  /// matcher didn't match.
  struct MockNotFoundError: Error {
    let request: HTTPRequest
    let body: HTTPBody?
    let baseURL: URL
  }
}

extension ClientTransport where Self == MockClientTransport {
  /// Creates a `MockClientTransport`.
  ///
  /// This enables ergonomic call sites like:
  ///
  /// ```swift
  /// let transport: MockClientTransport = .mock()
  /// ```
  public static func mock() -> Self {
    MockClientTransport()
  }
}

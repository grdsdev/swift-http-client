import Foundation
import HTTPTypes
import HTTPTypesFoundation

/// A protocol for intercepting HTTP client requests.
public protocol HTTPClientInterceptor: Sendable {
  /// Intercepts the HTTP request and performs additional processing.
  /// - Parameters:
  ///   - request: The HTTP request to intercept.
  ///   - next: The closure representing the next interceptor or the final request.
  /// - Returns: The intercepted response.
  func intercept(
    _ request: HTTPRequest,
    next: (HTTPRequest) async throws -> (Data, HTTPResponse)
  ) async throws -> (Data, HTTPResponse)
}

/// A protocol representing an HTTP client.
public protocol HTTPClientProtocol: Sendable {
  /// Sends an HTTP request and returns the response.
  /// - Parameter request: The request to send.
  /// - Returns: The response from the server.
  func send<Response>(_ request: Request<Response>) async throws -> Response
}

/// An actor-based implementation of the HTTP client.
public actor HTTPClient: HTTPClientProtocol {
  private let session: URLSession
  private let interceptors: [HTTPClientInterceptor]

  /// Initializes a new HTTP client.
  /// - Parameters:
  ///   - session: The URLSession to use for making requests.
  ///   - interceptors: The array of interceptors to apply to requests.
  public init(session: URLSession = .shared, interceptors: [HTTPClientInterceptor] = []) {
    self.session = session
    self.interceptors = interceptors
  }

  /// Sends an HTTP request and returns the response.
  /// - Parameter request: The request to send.
  /// - Returns: The response from the server.
  public func send<Response>(_ request: Request<Response>) async throws -> Response {
    var next: (HTTPRequest) async throws -> (Data, HTTPResponse) = { _request in
      try await self.session.data(for: _request)
    }

    for interceptor in interceptors.reversed() {
      let tmp = next
      next = {
        try await interceptor.intercept($0, next: tmp)
      }
    }

    let (data, response) = try await next(request.underlyingRequest)
    return try request.decode(data, response)
  }
}

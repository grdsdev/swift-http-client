import Foundation
import HTTPTypes
import HTTPTypesFoundation

/// Represents a network request.
public struct Request<Response: Sendable>: Sendable {
  /// The underlying HTTP request.
  let underlyingRequest: HTTPRequest
  /// The closure to decode the response data.
  let decode: @Sendable (Data, HTTPResponse) throws -> Response

  /// Initializes a new Request instance.
  /// - Parameters:
  ///   - underlyingRequest: The underlying HTTP request.
  ///   - decode: The closure to decode the response data.
  public init(
    _ underlyingRequest: HTTPRequest,
    decode: @escaping @Sendable (Data, HTTPResponse) throws -> Response
  ) {
    self.underlyingRequest = underlyingRequest
    self.decode = decode
  }
}

extension Request where Response: Decodable {
  /// Initializes a new Request instance for decodable responses.
  /// - Parameters:
  ///   - underlyingRequest: The underlying HTTP request.
  ///   - decoder: The JSON decoder to use for decoding the response data.
  public init(_ underlyingRequest: HTTPRequest, decoder: JSONDecoder = .init()) {
    self.init(underlyingRequest) { data, _ in
      try decoder.decode(Response.self, from: data)
    }
  }
}

extension Request where Response == Void {
  /// Initializes a new Request instance for void responses.
  /// - Parameter underlyingRequest: The underlying HTTP request.
  public init(_ underlyingRequest: HTTPRequest) {
    self.init(underlyingRequest) { _, _ in () }
  }
}

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

/// An enumeration representing HTTP client errors.
public enum HTTPClientError: Error {
  /// An error indicating an unsuccessful status code.
  case unsuccessfulStatusCode(code: HTTPResponse.Status, body: Data)
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

/// A struct for validating HTTP response status codes.
public struct StatusCodeValidator: HTTPClientInterceptor {
  /// The closure to validate the HTTP response status code.
  let validation: @Sendable (HTTPResponse.Status) -> Bool

  /// Initializes a new StatusCodeValidator instance.
  /// - Parameter validation: The closure to validate the HTTP response status code.
  public init(validation: @escaping @Sendable (HTTPResponse.Status) -> Bool) {
    self.validation = validation
  }

  /// Initializes a new StatusCodeValidator instance with a default validation for successful status codes.
  public init() {
    self.init { $0.kind == .successful }
  }

  /// Intercepts the HTTP request and performs additional processing.
  /// - Parameters:
  ///   - request: The HTTP request to intercept.
  ///   - next: The closure representing the next interceptor or the final request.
  /// - Returns: The intercepted response.
  public func intercept(
    _ request: HTTPRequest,
    next: (HTTPRequest) async throws -> (Data, HTTPResponse)
  ) async throws -> (Data, HTTPResponse) {
    let (data, response) = try await next(request)

    guard validation(response.status) else {
      throw HTTPClientError.unsuccessfulStatusCode(code: response.status, body: data)
    }

    return (data, response)
  }
}

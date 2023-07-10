import Foundation
import HTTPTypes

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

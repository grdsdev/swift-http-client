import Foundation
import HTTPTypes

/// Represents a network request.
public struct Request<Response: Sendable>: Sendable {
  /// The underlying HTTP request.
  public var underlyingRequest: HTTPRequest
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

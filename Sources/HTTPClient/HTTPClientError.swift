import Foundation
import HTTPTypes

/// An enumeration representing HTTP client errors.
public enum HTTPClientError: Error {
  /// An error indicating an unacceptable status code.
  case unacceptableStatusCode(code: HTTPResponse.Status, body: Data)
}

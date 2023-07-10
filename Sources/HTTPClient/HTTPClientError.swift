import Foundation
import HTTPTypes

/// An enumeration representing HTTP client errors.
public enum HTTPClientError: Error {
  /// An error indicating an unsuccessful status code.
  case unsuccessfulStatusCode(code: HTTPResponse.Status, body: Data)
}

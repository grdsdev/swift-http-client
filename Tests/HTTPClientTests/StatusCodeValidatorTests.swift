import HTTPClient
import XCTest

final class StatusCodeValidatorTests: XCTestCase {
  func test_statusCode() async throws {
    let sut = StatusCodeValidator()
    _ = try await sut.intercept(.mock()) { _ in
      (Data(), .init(status: .ok))
    }
  }

  func test_statusCode_shouldThrowError() async throws {
    let sut = StatusCodeValidator()
    do {
      _ = try await sut.intercept(.mock()) { _ in
        (Data(), .init(status: .preconditionFailed))
      }
      XCTFail("intercept should throw error")
    } catch let HTTPClientError.unacceptableStatusCode(code, body) {
      XCTAssertEqual(code, .preconditionFailed)
      XCTAssertEqual(body, Data())
    } catch {
      XCTFail("Unexpected error thrown \(error)")
    }
  }
}

extension HTTPRequest {
  static func mock() -> HTTPRequest {
    HTTPRequest(method: .get, scheme: "https", authority: "grds.dev", path: "/")
  }
}

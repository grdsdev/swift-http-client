import HTTPClient
import XCTest

final class HTTPClientTests: XCTestCase {
  func testHTTPClient() async throws {
    let sut = HTTPClient()
    let fact = try await sut.send(
      Request<String>(
        HTTPRequest(
          method: .get,
          url: URL(string: "http://numbersapi.com/random?min=10&max=20")!
        )
      )
    )
    XCTAssertFalse(fact.isEmpty)
  }
}

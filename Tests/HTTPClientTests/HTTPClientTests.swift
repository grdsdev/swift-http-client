import Foundation
import Logging
import Testing

@testable import HTTPClient

@Test func example() async throws {
  var logger = Logger(label: "HTTPClientTests")
  logger.logLevel = .trace

  let client = Client(
    serverURL: URL(string: "https://httpbin.org")!,
    transport: URLSessionTransport(),
    middlewares: [LoggingMiddleware(logger: logger)]
  )

  let (response, _) = try await client.send(
    HTTPRequest(method: .get, url: URL(string: "https://httpbin.org/get")!)
  )
  #expect(response.status.code == 200)
}

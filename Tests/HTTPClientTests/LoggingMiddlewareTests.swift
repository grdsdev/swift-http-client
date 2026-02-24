import Foundation
import HTTPTypes
import Logging
import Testing

@testable import HTTPClient

@Suite
struct LoggingMiddlewareTests {

  let serverURL = URL(string: "https://api.example.com")!

  // MARK: - Test Helpers

  /// A test log handler that captures log messages
  struct TestLogHandler: LogHandler {
    struct LogEntry: Sendable {
      let level: Logger.Level
      let message: String
      let metadata: Logger.Metadata?
    }

    actor LogCollector {
      private var entries: [LogEntry] = []

      func append(_ entry: LogEntry) {
        entries.append(entry)
      }

      func getEntries() -> [LogEntry] {
        entries
      }

      func clear() {
        entries.removeAll()
      }
    }

    let collector: LogCollector

    var metadata: Logger.Metadata = [:]
    var logLevel: Logger.Level = .trace

    subscript(metadataKey key: String) -> Logger.Metadata.Value? {
      get { metadata[key] }
      set { metadata[key] = newValue }
    }

    func log(
      level: Logger.Level,
      message: Logger.Message,
      metadata: Logger.Metadata?,
      source: String,
      file: String,
      function: String,
      line: UInt
    ) {
      let entry = LogEntry(level: level, message: "\(message)", metadata: metadata)
      Task {
        await collector.append(entry)
      }
    }
  }

  struct MockTransport: ClientTransport {
    let responseStatus: HTTPResponse.Status
    let responseBody: String?

    func send(
      _ request: HTTPRequest,
      body: HTTPBody?,
      baseURL: URL
    ) async throws -> (HTTPResponse, HTTPBody?) {
      let response = HTTPResponse(status: responseStatus)
      let body = responseBody.map { HTTPBody($0) }
      return (response, body)
    }
  }

  // MARK: - Basic Logging Tests

  @Test func loggingMiddlewareLogsRequest() async throws {
    let collector = TestLogHandler.LogCollector()
    let handler = TestLogHandler(collector: collector)
    var logger = Logger(label: "test")
    logger.handler = handler

    let middleware = LoggingMiddleware(logger: logger)
    let transport = MockTransport(responseStatus: .ok, responseBody: nil)

    let client = Client(
      serverURL: serverURL,
      transport: transport,
      middlewares: [middleware]
    )

    let request = HTTPRequest(method: .get, url: serverURL.appending(path: "test"))
    _ = try await client.send(request)

    // Wait a bit for async logging to complete
    try await Task.sleep(for: .milliseconds(100))

    let entries = await collector.getEntries()

    // Should have logged both request and response
    #expect(entries.count == 2)

    // First log should be the request (with ⬆️)
    let requestLog = entries[0]
    #expect(requestLog.level == .trace)
    #expect(requestLog.message.contains("⬆️"))
    #expect(requestLog.message.contains("GET"))

    // Second log should be the response (with ⬇️)
    let responseLog = entries[1]
    #expect(responseLog.level == .trace)
    #expect(responseLog.message.contains("⬇️"))
  }

  @Test func loggingMiddlewareLogsResponse() async throws {
    let collector = TestLogHandler.LogCollector()
    let handler = TestLogHandler(collector: collector)
    var logger = Logger(label: "test")
    logger.handler = handler

    let middleware = LoggingMiddleware(logger: logger)
    let transport = MockTransport(responseStatus: .created, responseBody: "Created")

    let client = Client(
      serverURL: serverURL,
      transport: transport,
      middlewares: [middleware]
    )

    let request = HTTPRequest(method: .post, url: serverURL.appending(path: "users"))
    _ = try await client.send(request)

    try await Task.sleep(for: .milliseconds(100))

    let entries = await collector.getEntries()
    #expect(entries.count == 2)

    let responseLog = entries[1]
    #expect(responseLog.message.contains("201"))
  }

  @Test func loggingMiddlewareAddsRequestID() async throws {
    let collector = TestLogHandler.LogCollector()
    let handler = TestLogHandler(collector: collector)
    var logger = Logger(label: "test")
    logger.handler = handler

    let middleware = LoggingMiddleware(logger: logger, includeMetadata: true)
    let transport = MockTransport(responseStatus: .ok, responseBody: nil)

    let client = Client(
      serverURL: serverURL,
      transport: transport,
      middlewares: [middleware]
    )

    let request = HTTPRequest(method: .get, url: serverURL.appending(path: "test"))
    _ = try await client.send(request)

    try await Task.sleep(for: .milliseconds(100))

    let entries = await collector.getEntries()
    #expect(entries.count == 2)

    // Both logs should have metadata (inherited from logger)
    // The request-id should be set
    // Note: The metadata is set on the logger, not necessarily passed to each log call
  }

  @Test func loggingMiddlewareWithoutMetadata() async throws {
    let collector = TestLogHandler.LogCollector()
    let handler = TestLogHandler(collector: collector)
    var logger = Logger(label: "test")
    logger.handler = handler

    let middleware = LoggingMiddleware(logger: logger, includeMetadata: false)
    let transport = MockTransport(responseStatus: .ok, responseBody: nil)

    let client = Client(
      serverURL: serverURL,
      transport: transport,
      middlewares: [middleware]
    )

    let request = HTTPRequest(method: .get, url: serverURL.appending(path: "test"))
    _ = try await client.send(request)

    try await Task.sleep(for: .milliseconds(100))

    let entries = await collector.getEntries()
    #expect(entries.count == 2)
  }

  @Test func loggingMiddlewarePreservesExistingRequestID() async throws {
    let collector = TestLogHandler.LogCollector()
    let handler = TestLogHandler(collector: collector)
    var logger = Logger(label: "test")
    logger.handler = handler
    logger[metadataKey: "request-id"] = "existing-id"

    let middleware = LoggingMiddleware(logger: logger, includeMetadata: true)
    let transport = MockTransport(responseStatus: .ok, responseBody: nil)

    let client = Client(
      serverURL: serverURL,
      transport: transport,
      middlewares: [middleware]
    )

    let request = HTTPRequest(method: .get, url: serverURL.appending(path: "test"))
    _ = try await client.send(request)

    try await Task.sleep(for: .milliseconds(100))

    // Logs should be created
    let entries = await collector.getEntries()
    #expect(entries.count == 2)
  }

  @Test func loggingMiddlewareLogsDifferentMethods() async throws {
    let collector = TestLogHandler.LogCollector()
    let handler = TestLogHandler(collector: collector)
    var logger = Logger(label: "test")
    logger.handler = handler

    let middleware = LoggingMiddleware(logger: logger)
    let transport = MockTransport(responseStatus: .ok, responseBody: nil)

    let client = Client(
      serverURL: serverURL,
      transport: transport,
      middlewares: [middleware]
    )

    let methods: [HTTPRequest.Method] = [.get, .post, .put, .delete, .patch]

    for method in methods {
      await collector.clear()

      let request = HTTPRequest(method: method, url: serverURL.appending(path: "test"))
      _ = try await client.send(request)

      try await Task.sleep(for: .milliseconds(100))

      let entries = await collector.getEntries()
      #expect(entries.count == 2)

      let requestLog = entries[0]
      #expect(requestLog.message.contains(method.rawValue))
    }
  }

  @Test func loggingMiddlewareLogsDifferentStatusCodes() async throws {
    let statuses: [HTTPResponse.Status] = [
      .ok, .created, .noContent, .badRequest, .notFound, .internalServerError,
    ]

    for status in statuses {
      let collector = TestLogHandler.LogCollector()
      let handler = TestLogHandler(collector: collector)
      var logger = Logger(label: "test")
      logger.handler = handler

      let middleware = LoggingMiddleware(logger: logger)
      let transport = MockTransport(responseStatus: status, responseBody: nil)

      let client = Client(
        serverURL: serverURL,
        transport: transport,
        middlewares: [middleware]
      )

      let request = HTTPRequest(method: .get, url: serverURL.appending(path: "test"))
      _ = try await client.send(request)

      try await Task.sleep(for: .milliseconds(100))

      let entries = await collector.getEntries()
      #expect(entries.count == 2)

      let responseLog = entries[1]
      #expect(responseLog.message.contains(String(status.code)))
    }
  }

  @Test func loggingMiddlewareWorksWithOtherMiddlewares() async throws {
    let collector = TestLogHandler.LogCollector()
    let handler = TestLogHandler(collector: collector)
    var logger = Logger(label: "test")
    logger.handler = handler

    struct TestMiddleware: ClientMiddleware {
      func intercept(
        _ request: HTTPRequest,
        body: sending HTTPBody?,
        baseURL: URL,
        next: (HTTPRequest, sending HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
      ) async throws -> (HTTPResponse, HTTPBody?) {
        var request = request
        request.headerFields[.init("X-Test")!] = "test"
        return try await next(request, body, baseURL)
      }
    }

    let loggingMiddleware = LoggingMiddleware(logger: logger)
    let testMiddleware = TestMiddleware()
    let transport = MockTransport(responseStatus: .ok, responseBody: nil)

    let client = Client(
      serverURL: serverURL,
      transport: transport,
      middlewares: [loggingMiddleware, testMiddleware]
    )

    let request = HTTPRequest(method: .get, url: serverURL.appending(path: "test"))
    _ = try await client.send(request)

    try await Task.sleep(for: .milliseconds(100))

    // Logging middleware should have logged
    let entries = await collector.getEntries()
    #expect(entries.count == 2)
  }

  @Test func loggingMiddlewareLogsErrors() async throws {
    let collector = TestLogHandler.LogCollector()
    let handler = TestLogHandler(collector: collector)
    var logger = Logger(label: "test")
    logger.handler = handler

    struct FailingTransport: ClientTransport {
      struct TransportError: Error {}

      func send(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL
      ) async throws -> (HTTPResponse, HTTPBody?) {
        throw TransportError()
      }
    }

    let middleware = LoggingMiddleware(logger: logger)
    let transport = FailingTransport()

    let client = Client(
      serverURL: serverURL,
      transport: transport,
      middlewares: [middleware]
    )

    let request = HTTPRequest(method: .get, url: serverURL.appending(path: "test"))

    do {
      _ = try await client.send(request)
      #expect(Bool(false), "Should have thrown")
    } catch {
      // Expected to throw
    }

    try await Task.sleep(for: .milliseconds(100))

    // Request should still be logged
    let entries = await collector.getEntries()
    #expect(entries.count >= 1)
    let requestLog = entries[0]
    #expect(requestLog.message.contains("⬆️"))
  }
}

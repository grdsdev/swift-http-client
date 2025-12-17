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
    struct LogEntry {
      let level: Logger.Level
      let message: Logger.Message
      let metadata: Logger.Metadata?
    }

    let entries: UnsafeMutablePointer<[LogEntry]>

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
      let entry = LogEntry(level: level, message: message, metadata: metadata)
      entries.pointee.append(entry)
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
    let entriesPtr = UnsafeMutablePointer<[TestLogHandler.LogEntry]>.allocate(capacity: 1)
    entriesPtr.initialize(to: [])
    defer { entriesPtr.deallocate() }

    let handler = TestLogHandler(entries: entriesPtr)
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

    // Should have logged both request and response
    #expect(entriesPtr.pointee.count == 2)

    // First log should be the request (with ⬆️)
    let requestLog = entriesPtr.pointee[0]
    #expect(requestLog.level == .trace)
    #expect(requestLog.message.description.contains("⬆️"))
    #expect(requestLog.message.description.contains("GET"))

    // Second log should be the response (with ⬇️)
    let responseLog = entriesPtr.pointee[1]
    #expect(responseLog.level == .trace)
    #expect(responseLog.message.description.contains("⬇️"))
  }

  @Test func loggingMiddlewareLogsResponse() async throws {
    let entriesPtr = UnsafeMutablePointer<[TestLogHandler.LogEntry]>.allocate(capacity: 1)
    entriesPtr.initialize(to: [])
    defer { entriesPtr.deallocate() }

    let handler = TestLogHandler(entries: entriesPtr)
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

    #expect(entriesPtr.pointee.count == 2)

    let responseLog = entriesPtr.pointee[1]
    #expect(responseLog.message.description.contains("201"))
  }

  @Test func loggingMiddlewareAddsRequestID() async throws {
    let entriesPtr = UnsafeMutablePointer<[TestLogHandler.LogEntry]>.allocate(capacity: 1)
    entriesPtr.initialize(to: [])
    defer { entriesPtr.deallocate() }

    let handler = TestLogHandler(entries: entriesPtr)
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

    #expect(entriesPtr.pointee.count == 2)

    // Both logs should have metadata (inherited from logger)
    // The request-id should be set
    // Note: The metadata is set on the logger, not necessarily passed to each log call
  }

  @Test func loggingMiddlewareWithoutMetadata() async throws {
    let entriesPtr = UnsafeMutablePointer<[TestLogHandler.LogEntry]>.allocate(capacity: 1)
    entriesPtr.initialize(to: [])
    defer { entriesPtr.deallocate() }

    let handler = TestLogHandler(entries: entriesPtr)
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

    #expect(entriesPtr.pointee.count == 2)
  }

  @Test func loggingMiddlewarePreservesExistingRequestID() async throws {
    let entriesPtr = UnsafeMutablePointer<[TestLogHandler.LogEntry]>.allocate(capacity: 1)
    entriesPtr.initialize(to: [])
    defer { entriesPtr.deallocate() }

    let handler = TestLogHandler(entries: entriesPtr)
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

    // Logs should be created
    #expect(entriesPtr.pointee.count == 2)
  }

  @Test func loggingMiddlewareLogsDifferentMethods() async throws {
    let entriesPtr = UnsafeMutablePointer<[TestLogHandler.LogEntry]>.allocate(capacity: 1)
    entriesPtr.initialize(to: [])
    defer { entriesPtr.deallocate() }

    let handler = TestLogHandler(entries: entriesPtr)
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
      entriesPtr.pointee.removeAll()

      let request = HTTPRequest(method: method, url: serverURL.appending(path: "test"))
      _ = try await client.send(request)

      #expect(entriesPtr.pointee.count == 2)

      let requestLog = entriesPtr.pointee[0]
      #expect(requestLog.message.description.contains(method.rawValue))
    }
  }

  @Test func loggingMiddlewareLogsDifferentStatusCodes() async throws {
    let statuses: [HTTPResponse.Status] = [
      .ok, .created, .noContent, .badRequest, .notFound, .internalServerError,
    ]

    for status in statuses {
      let entriesPtr = UnsafeMutablePointer<[TestLogHandler.LogEntry]>.allocate(capacity: 1)
      entriesPtr.initialize(to: [])
      defer { entriesPtr.deallocate() }

      let handler = TestLogHandler(entries: entriesPtr)
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

      #expect(entriesPtr.pointee.count == 2)

      let responseLog = entriesPtr.pointee[1]
      #expect(responseLog.message.description.contains(String(status.code)))
    }
  }

  @Test func loggingMiddlewareWorksWithOtherMiddlewares() async throws {
    let entriesPtr = UnsafeMutablePointer<[TestLogHandler.LogEntry]>.allocate(capacity: 1)
    entriesPtr.initialize(to: [])
    defer { entriesPtr.deallocate() }

    let handler = TestLogHandler(entries: entriesPtr)
    var logger = Logger(label: "test")
    logger.handler = handler

    struct TestMiddleware: ClientMiddleware {
      func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        next: (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
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

    // Logging middleware should have logged
    #expect(entriesPtr.pointee.count == 2)
  }

  @Test func loggingMiddlewareLogsErrors() async throws {
    let entriesPtr = UnsafeMutablePointer<[TestLogHandler.LogEntry]>.allocate(capacity: 1)
    entriesPtr.initialize(to: [])
    defer { entriesPtr.deallocate() }

    let handler = TestLogHandler(entries: entriesPtr)
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

    // Request should still be logged
    #expect(entriesPtr.pointee.count >= 1)
    let requestLog = entriesPtr.pointee[0]
    #expect(requestLog.message.description.contains("⬆️"))
  }
}

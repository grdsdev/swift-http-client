import Foundation
import HTTPTypes
import Logging
import Testing

@testable import HTTPClient

/// Integration tests using httpbingo.org API to verify real HTTP scenarios
///
/// - Note: These tests require httpbingo.org running on port 8081.
/// Use: `$ go run github.com/mccutchen/go-httpbin/v2/cmd/go-httpbin@latest -host 127.0.0.1 -port 8081`
@Suite
struct IntegrationTests {

  let serverURL = URL(string: "http://127.0.0.1:8081")!
  let client: Client

  init() {
    client = Client(
      serverURL: serverURL,
      transport: URLSessionTransport()
    )
  }

  // MARK: - Basic HTTP Methods

  @Test func getRequest() async throws {
    let request = HTTPRequest(method: .get, url: serverURL.appending(path: "get"))
    let (response, body) = try await client.send(request)

    #expect(response.status == .ok)
    #expect(response.headerFields[.contentType]?.contains("application/json") == true)

    let json = try #require(try await body?.json() as? [String: Any])
    #expect(json["url"] != nil)
  }

  @Test func postRequest() async throws {
    let request = HTTPRequest(
      method: .post, url: serverURL.appending(path: "post"),
      headerFields: [.contentType: "text/plain"])
    let requestBody = HTTPBody("Test data")

    let (response, body) = try await client.send(request, body: requestBody)

    #expect(response.status == .ok)

    let json = try #require(try await body?.json() as? [String: Any])
    #expect(json["data"] as? String == "Test data")
  }

  @Test func putRequest() async throws {
    let request = HTTPRequest(
      method: .put, url: serverURL.appending(path: "put"),
      headerFields: [.contentType: "text/plain"])
    let requestBody = HTTPBody("Updated data")

    let (response, body) = try await client.send(request, body: requestBody)

    #expect(response.status == .ok)

    let json = try #require(try await body?.json() as? [String: Any])
    #expect(json["data"] as? String == "Updated data")
  }

  @Test func deleteRequest() async throws {
    let request = HTTPRequest(method: .delete, url: serverURL.appending(path: "delete"))
    let (response, _) = try await client.send(request)

    #expect(response.status == .ok)
  }

  @Test func patchRequest() async throws {
    let request = HTTPRequest(
      method: .patch, url: serverURL.appending(path: "patch"),
      headerFields: [.contentType: "text/plain"])
    let requestBody = HTTPBody("Patched data")

    let (response, body) = try await client.send(request, body: requestBody)

    #expect(response.status == .ok)

    let json = try #require(try await body?.json() as? [String: Any])
    #expect(json["data"] as? String == "Patched data")
  }

  // MARK: - Headers

  @Test func customHeaders() async throws {
    var request = HTTPRequest(method: .get, url: serverURL.appending(path: "headers"))
    request.headerFields[.init("X-Custom-Header")!] = "custom-value"
    request.headerFields[.init("X-Another-Header")!] = "another-value"

    let (response, body) = try await client.send(request)

    #expect(response.status == .ok)

    let json = try #require(try await body?.json() as? [String: Any])
    let headers = try #require(json["headers"] as? [String: [String]])

    #expect(headers["X-Custom-Header"] == ["custom-value"])
    #expect(headers["X-Another-Header"] == ["another-value"])
  }

  @Test func userAgentHeader() async throws {
    var request = HTTPRequest(method: .get, url: serverURL.appending(path: "user-agent"))
    request.headerFields[.userAgent] = "SwiftHTTPClient/1.0"

    let (response, body) = try await client.send(request)

    #expect(response.status == .ok)

    let json = try #require(try await body?.json() as? [String: Any])
    #expect((json["user-agent"] as? String)?.contains("SwiftHTTPClient/1.0") == true)
  }

  @Test func authorizationHeader() async throws {
    var request = HTTPRequest(method: .get, url: serverURL.appending(path: "bearer"))
    request.headerFields[.authorization] = "Bearer test-token"

    let (response, body) = try await client.send(request)

    #expect(response.status == .ok)

    let json = try #require(try await body?.json() as? [String: Any])
    #expect(json["authenticated"] as? Bool == true)
    #expect(json["token"] as? String == "test-token")
  }

  // MARK: - Status Codes

  @Test func statusCode200() async throws {
    let request = HTTPRequest(
      method: .get,
      url: serverURL.appending(path: "status/200")
    )
    let (response, _) = try await client.send(request)
    #expect(response.status == .ok)
  }

  @Test func statusCode201() async throws {
    let request = HTTPRequest(
      method: .get,
      url: serverURL.appending(path: "status/201")
    )
    let (response, _) = try await client.send(request)
    #expect(response.status == .created)
  }

  @Test func statusCode204() async throws {
    let request = HTTPRequest(
      method: .get,
      url: serverURL.appending(path: "status/204")
    )
    let (response, _) = try await client.send(request)
    #expect(response.status == .noContent)
  }

  @Test func statusCode400() async throws {
    let request = HTTPRequest(
      method: .get,
      url: serverURL.appending(path: "status/400")
    )
    let (response, _) = try await client.send(request)
    #expect(response.status == .badRequest)
  }

  @Test func statusCode404() async throws {
    let request = HTTPRequest(
      method: .get,
      url: serverURL.appending(path: "status/404")
    )
    let (response, _) = try await client.send(request)
    #expect(response.status == .notFound)
  }

  @Test func statusCode500() async throws {
    let request = HTTPRequest(
      method: .get,
      url: serverURL.appending(path: "status/500")
    )
    let (response, _) = try await client.send(request)
    #expect(response.status == .internalServerError)
  }

  // MARK: - Response Formats

  @Test func jsonResponse() async throws {
    let request = HTTPRequest(method: .get, url: serverURL.appending(path: "json"))
    let (response, body) = try await client.send(request)

    #expect(response.status == .ok)
    #expect(response.headerFields[.contentType]?.contains("application/json") == true)

    let json = try #require(try await body?.json() as? [String: Any])
    #expect(json.keys.count > 0)
  }

  @Test func htmlResponse() async throws {
    let request = HTTPRequest(method: .get, url: serverURL.appending(path: "html"))
    let (response, body) = try await client.send(request)

    #expect(response.status == .ok)
    #expect(response.headerFields[.contentType]?.contains("text/html") == true)

    let html = try await String(collecting: try #require(body), upTo: 1024 * 1024)
    #expect(html.contains("<html>"))
  }

  @Test func utf8Response() async throws {
    let request = HTTPRequest(
      method: .get, url: serverURL.appending(path: "encoding/utf8"))
    let (response, body) = try await client.send(request)

    #expect(response.status == .ok)

    let content = try await String(collecting: try #require(body), upTo: 1024 * 1024)
    #expect(content.contains("UTF-8"))
  }

  // MARK: - Request Data

  @Test func postJSON() async throws {
    var request = HTTPRequest(method: .post, url: serverURL.appending(path: "post"))
    request.headerFields[.contentType] = "application/json"

    let jsonData = """
      {"name": "John Doe", "age": 30}
      """
    let requestBody = HTTPBody(jsonData)

    let (response, body) = try await client.send(request, body: requestBody)

    #expect(response.status == .ok)

    let json = try #require(try await body?.json() as? [String: Any])
    let data = try #require(json["data"] as? String)
    #expect(data.contains("John Doe"))
  }

  @Test func postFormData() async throws {
    var request = HTTPRequest(method: .post, url: serverURL.appending(path: "post"))
    request.headerFields[.contentType] = "application/x-www-form-urlencoded"

    let formData = "name=John&email=john@example.com"
    let requestBody = HTTPBody(formData)

    let (response, body) = try await client.send(request, body: requestBody)

    #expect(response.status == .ok)

    let json = try #require(try await body?.json() as? [String: Any])
    #expect(json["data"] as? String == formData)
  }

  // MARK: - Response Headers

  @Test func responseHeaders() async throws {
    let request = HTTPRequest(
      method: .get,
      url: serverURL.appending(path: "response-headers").appending(queryItems: [
        URLQueryItem(name: "X-Test", value: "test-value")
      ])
    )
    let (response, _) = try await client.send(request)

    #expect(response.status == .ok)
    #expect(response.headerFields[.init("X-Test")!] == "test-value")
  }

  // MARK: - Cookies (if supported by httpbin)

  // @Test func getCookies() async throws {
  //   let request = HTTPRequest(
  //     method: .get,
  //     url: serverURL.appending(path: "cookies")
  //   )
  //   let (response, body) = try await client.send(request)

  //   #expect(response.status == .ok)

  //   let json = try #require(try await body?.json() as? [String: Any])
  //   #expect(json["cookies"] != nil)
  // }

  // MARK: - Redirects

  @Test func absoluteRedirect() async throws {
    let request = HTTPRequest(
      method: .get,
      url: serverURL.appending(path: "absolute-redirect/1")
    )
    let (response, _) = try await client.send(request)

    // URLSession follows redirects by default
    #expect(response.status == .ok)
  }

  // MARK: - Request Inspection

  @Test func requestInspection() async throws {
    var request = HTTPRequest(
      method: .get,
      url: serverURL.appending(path: "get").appending(queryItems: [
        URLQueryItem(name: "param1", value: "value1"),
        URLQueryItem(name: "param2", value: "value2"),
      ])
    )
    request.headerFields[.accept] = "application/json"

    let (response, body) = try await client.send(request)

    #expect(response.status == .ok)

    let json = try #require(try await body?.json() as? [String: Any])

    // Verify query parameters
    let args = try #require(json["args"] as? [String: [String]])
    #expect(args["param1"] == ["value1"])
    #expect(args["param2"] == ["value2"])

    // Verify headers
    let headers = try #require(json["headers"] as? [String: [String]])
    #expect(headers["Accept"] == ["application/json"])
  }

  // MARK: - Large Responses

  @Test func largeResponse() async throws {
    // Get 100KB of random bytes
    let request = HTTPRequest(
      method: .get,
      url: serverURL.appending(path: "bytes/102400")
    )
    let (response, body) = try await client.send(request)

    #expect(response.status == .ok)

    let data = try await Data(collecting: try #require(body), upTo: 1024 * 1024)
    #expect(data.count == 102400)
  }

  // MARK: - Streaming

  @Test func streamResponse() async throws {
    let request = HTTPRequest(
      method: .get,
      url: serverURL.appending(path: "stream/10")
    )
    let (response, body) = try await client.send(request)

    #expect(response.status == .ok)

    var lineCount = 0
    for try await _ in try #require(body) {
      lineCount += 1
    }

    #expect(lineCount > 0)
  }

  // MARK: - Delay

  @Test func delayedResponse() async throws {
    let start = Date()
    let request = HTTPRequest(
      method: .get,
      url: serverURL.appending(path: "delay/1")
    )
    let (response, _) = try await client.send(request)

    let elapsed = Date().timeIntervalSince(start)

    #expect(response.status == .ok)
    #expect(elapsed >= 1.0)
  }

  // MARK: - Middleware Integration

  @Test func integrationWithAuthMiddleware() async throws {
    struct AuthMiddleware: ClientMiddleware {
      let token: String

      func intercept(
        _ request: HTTPRequest,
        body: sending HTTPBody?,
        baseURL: URL,
        next: (HTTPRequest, sending HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
      ) async throws -> (HTTPResponse, HTTPBody?) {
        var request = request
        request.headerFields[.authorization] = "Bearer \(token)"
        return try await next(request, body, baseURL)
      }
    }

    let client = Client(
      serverURL: serverURL,
      transport: URLSessionTransport(),
      middlewares: [AuthMiddleware(token: "integration-test-token")]
    )

    let request = HTTPRequest(method: .get, url: serverURL.appending(path: "bearer"))
    let (response, body) = try await client.send(request)

    #expect(response.status == .ok)

    let json = try #require(try await body?.json() as? [String: Any])
    #expect(json["authenticated"] as? Bool == true)
    #expect(json["token"] as? String == "integration-test-token")
  }

  @Test func integrationWithLoggingMiddleware() async throws {
    let logger = Logger(label: "integration-test")

    let client = Client(
      serverURL: serverURL,
      transport: URLSessionTransport(),
      middlewares: [LoggingMiddleware(logger: logger)]
    )

    let request = HTTPRequest(method: .get, url: serverURL.appending(path: "get"))
    let (response, _) = try await client.send(request)

    #expect(response.status == .ok)
  }

  @Test func integrationWithMultipleMiddlewares() async throws {
    struct UserAgentMiddleware: ClientMiddleware {
      func intercept(
        _ request: HTTPRequest,
        body: sending HTTPBody?,
        baseURL: URL,
        next: (HTTPRequest, sending HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
      ) async throws -> (HTTPResponse, HTTPBody?) {
        var request = request
        request.headerFields[.userAgent] = "SwiftHTTPClient/Integration"
        return try await next(request, body, baseURL)
      }
    }

    struct AcceptMiddleware: ClientMiddleware {
      func intercept(
        _ request: HTTPRequest,
        body: sending HTTPBody?,
        baseURL: URL,
        next: (HTTPRequest, sending HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
      ) async throws -> (HTTPResponse, HTTPBody?) {
        var request = request
        request.headerFields[.accept] = "application/json"
        return try await next(request, body, baseURL)
      }
    }

    let client = Client(
      serverURL: serverURL,
      transport: URLSessionTransport(),
      middlewares: [UserAgentMiddleware(), AcceptMiddleware()]
    )

    let request = HTTPRequest(method: .get, url: serverURL.appending(path: "headers"))
    let (response, body) = try await client.send(request)

    #expect(response.status == .ok)

    let json = try #require(try await body?.json() as? [String: Any])
    let headers = try #require(json["headers"] as? [String: [String]])

    #expect(headers["User-Agent"]?.first?.contains("SwiftHTTPClient/Integration") == true)
    #expect(headers["Accept"] == ["application/json"])
  }

  // MARK: - Concurrent Requests

  @Test func concurrentRequests() async throws {
    let client = Client(
      serverURL: serverURL,
      transport: URLSessionTransport()
    )

    await withTaskGroup(of: Bool.self) { group in
      for i in 0..<10 {
        group.addTask {
          let request = HTTPRequest(
            method: .get,
            url: serverURL.appending(path: "get").appending(queryItems: [
              URLQueryItem(name: "id", value: "\(i)")
            ])
          )
          if let (response, _) = try? await client.send(request) {
            return response.status == .ok
          }
          return false
        }
      }

      var successCount = 0
      for await success in group {
        if success {
          successCount += 1
        }
      }

      #expect(successCount == 10)
    }
  }
}

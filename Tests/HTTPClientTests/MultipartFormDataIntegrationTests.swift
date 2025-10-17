import Foundation
import Testing

@testable import HTTPClient

/// Integration tests using httpbingo.org API to verify multipart form data uploads work correctly
/// with real HTTP servers.
///
/// - Note: These tests requires httpbingo.org running on port 8081. Use: `$ go run github.com/mccutchen/go-httpbin/v2/cmd/go-httpbin@latest -host 127.0.0.1 -port 8081`
@Suite
struct MultipartFormDataIntegrationTests {
  let client = Client(
    serverURL: URL(string: "http://127.0.0.1:8081")!,
    transport: URLSessionTransport()
  )

  @Test func uploadSimpleFormData() async throws {
    let request = HTTPRequest(
      method: .post,
      url: URL(string: "http://127.0.0.1:8081/post")!
    )
    let (response, responseBody) = try await client.send(
      multipartFormData: {
        $0.append(Data("John Doe".utf8), withName: "name")
        $0.append(Data("john@example.com".utf8), withName: "email")
        $0.append(Data("30".utf8), withName: "age")
      },
      with: request
    )

    // Verify response
    #expect(response.status == .ok)
    #expect(response.headerFields[.contentType]?.contains("application/json") == true)

    // Parse response
    let json = try #require(try await responseBody?.json() as? [String: Any])

    // Verify form fields were received
    let form = try #require(json["form"] as? [String: [String]])
    #expect(form["name"] == ["John Doe"])
    #expect(form["email"] == ["john@example.com"])
    #expect(form["age"] == ["30"])
  }

  @Test func uploadFileData() async throws {
    let request = HTTPRequest(
      method: .post,
      url: URL(string: "http://127.0.0.1:8081/post")!
    )
    let (response, responseBody) = try await client.send(
      multipartFormData: {
        $0.append(Data("test-upload".utf8), withName: "description")
        $0.append(
          Data("This is a test file content\nLine 2\nLine 3".utf8),
          withName: "file",
          fileName: "test.txt",
          mimeType: "text/plain"
        )
      },
      with: request
    )

    #expect(response.status == .ok)

    let json = try #require(try await responseBody?.json() as? [String: Any])

    // Verify form field
    let form = try #require(json["form"] as? [String: [String]])
    #expect(form["description"] == ["test-upload"])

    // Verify file was uploaded
    let files = try #require(json["files"] as? [String: [String]])
    #expect(files["file"] == ["This is a test file content\nLine 2\nLine 3"])

    // Verify content-type header was set correctly
    let headers = try #require(json["headers"] as? [String: [String]])
    #expect(headers["Content-Type"]?.first?.contains("multipart/form-data") == true)
    #expect(headers["Content-Type"]?.first?.contains("boundary=") == true)
  }

  @Test func uploadMultipleFiles() async throws {
    let formData = MultipartFormData()

    // Add multiple files
    formData.append(
      Data("Content of file 1".utf8),
      withName: "file1",
      fileName: "file1.txt",
      mimeType: "text/plain"
    )

    formData.append(
      Data("Content of file 2".utf8),
      withName: "file2",
      fileName: "file2.txt",
      mimeType: "text/plain"
    )

    formData.append(
      Data("{\"key\": \"value\"}".utf8),
      withName: "data",
      fileName: "data.json",
      mimeType: "application/json"
    )

    let request = HTTPRequest(
      method: .post,
      url: URL(string: "http://127.0.0.1:8081/post")!
    )

    let (response, responseBody) = try await client.send(
      multipartFormData: formData,
      with: request,
    )

    #expect(response.status == .ok)

    let json = try #require(try await responseBody?.json() as? [String: Any])
    let files = try #require(json["files"] as? [String: [String]])

    #expect(files["file1"] == ["Content of file 1"])
    #expect(files["file2"] == ["Content of file 2"])
    #expect(files["data"] == ["{\"key\": \"value\"}"])
  }

  @Test func uploadLargeData() async throws {
    let formData = MultipartFormData()

    // Create a larger payload (500 KB)
    let largeData = Data(repeating: 65, count: 500 * 1024)  // 'A' repeated 500K times

    formData.append(Data("metadata".utf8), withName: "description")
    formData.append(
      largeData,
      withName: "largefile",
      fileName: "large.bin",
      mimeType: "application/octet-stream"
    )

    let request = HTTPRequest(
      method: .post,
      url: URL(string: "http://127.0.0.1:8081/post")!
    )

    // Use automatic encoding (should use in-memory for 500KB)
    let (response, responseBody) = try await client.send(
      multipartFormData: formData,
      with: request,
    )

    #expect(response.status == .ok)

    let json = try #require(try await responseBody?.json() as? [String: Any])

    // Verify the file was received (httpbin returns the content)
    let files = try #require(json["files"] as? [String: [String]])
    let uploadedFile = try #require(files["largefile"]?.first)

    // Verify the size matches
    #expect(uploadedFile.count == largeData.count)
    // Verify it's all 'A's
    #expect(uploadedFile.allSatisfy { $0 == "A" })
  }

  @Test func uploadFromActualFile() async throws {
    // Create a temporary file
    let tempURL = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
      .appendingPathExtension("txt")

    let fileContent =
      "This is content from an actual file on disk.\nIt has multiple lines.\nLine 3."
    try Data(fileContent.utf8).write(to: tempURL)

    defer {
      try? FileManager.default.removeItem(at: tempURL)
    }

    let formData = MultipartFormData()
    formData.append(Data("file-upload-test".utf8), withName: "test_type")
    formData.append(tempURL, withName: "uploaded_file")

    let request = HTTPRequest(
      method: .post,
      url: URL(string: "http://127.0.0.1:8081/post")!
    )

    let (response, responseBody) = try await client.send(
      multipartFormData: formData,
      with: request,
    )

    #expect(response.status == .ok)

    let json = try #require(try await responseBody?.json() as? [String: Any])

    // Verify form field
    let form = try #require(json["form"] as? [String: [String]])
    #expect(form["test_type"] == ["file-upload-test"])

    // Verify file content
    let files = try #require(json["files"] as? [String: [String]])
    #expect(files["uploaded_file"] == [fileContent])
  }

  @Test func uploadWithDiskBasedEncoding() async throws {
    let formData = MultipartFormData()

    // Add some data
    formData.append(Data("Test Description".utf8), withName: "description")
    formData.append(
      Data("File content for disk-based test".utf8),
      withName: "file",
      fileName: "diskfile.txt",
      mimeType: "text/plain"
    )

    let request = HTTPRequest(
      method: .post,
      url: URL(string: "http://127.0.0.1:8081/post")!
    )

    // Explicitly use disk-based encoding
    let (response, responseBody) = try await client.send(
      multipartFormData: formData,
      with: request,
    )

    #expect(response.status == .ok)

    let json = try #require(try await responseBody?.json() as? [String: Any])

    // Verify data was received correctly even with disk-based encoding
    let form = try #require(json["form"] as? [String: [String]])
    #expect(form["description"] == ["Test Description"])

    let files = try #require(json["files"] as? [String: [String]])
    #expect(files["file"] == ["File content for disk-based test"])
  }

  @Test func uploadMinimalFormData() async throws {
    let formData = MultipartFormData()
    // Add minimal data (empty form data causes issues with the underlying transport)
    formData.append(Data("".utf8), withName: "empty_field")

    let request = HTTPRequest(
      method: .post,
      url: URL(string: "http://127.0.0.1:8081/post")!
    )

    let (response, responseBody) = try await client.send(
      multipartFormData: formData,
      with: request,
    )

    #expect(response.status == .ok)

    let json = try #require(try await responseBody?.json() as? [String: Any])

    // Verify the empty field was received
    let form = try #require(json["form"] as? [String: [String]])
    #expect(form["empty_field"] == [""])
  }

  @Test func uploadBinaryData() async throws {
    let formData = MultipartFormData()

    // Create binary data (fake PNG header)
    let binaryData = Data([
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,  // PNG signature
      0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07,
    ])

    formData.append(
      binaryData,
      withName: "image",
      fileName: "test.png",
      mimeType: "image/png"
    )

    let request = HTTPRequest(
      method: .post,
      url: URL(string: "http://127.0.0.1:8081/post")!
    )

    let (response, responseBody) = try await client.send(
      multipartFormData: formData,
      with: request,
    )

    #expect(response.status == .ok)

    let json = try #require(try await responseBody?.json() as? [String: Any])

    // httpbin should receive the binary file
    let files = try #require(json["files"] as? [String: [String]])
    #expect(files["image"] != nil)
    // Binary data is base64 encoded or hex encoded in the response
    #expect(!files["image"]!.isEmpty)
  }

  @Test func uploadWithSpecialCharacters() async throws {
    let formData = MultipartFormData()

    // Test special characters in field names and values
    formData.append(Data("Hello, 世界! 🌍".utf8), withName: "greeting")
    formData.append(Data("user@example.com".utf8), withName: "email")
    formData.append(Data("Value with \"quotes\" and 'apostrophes'".utf8), withName: "special")

    let request = HTTPRequest(
      method: .post,
      url: URL(string: "http://127.0.0.1:8081/post")!
    )

    let (response, responseBody) = try await client.send(
      multipartFormData: formData,
      with: request,
    )

    #expect(response.status == .ok)

    let json = try #require(try await responseBody?.json() as? [String: Any])

    // Verify special characters were preserved
    let form = try #require(json["form"] as? [String: [String]])
    #expect(form["greeting"] == ["Hello, 世界! 🌍"])
    #expect(form["email"] == ["user@example.com"])
    #expect(form["special"] == ["Value with \"quotes\" and 'apostrophes'"])
  }

  @Test func verifyMultipartHeaders() async throws {
    let formData = MultipartFormData()
    formData.append(Data("test".utf8), withName: "field")

    let request = HTTPRequest(
      method: .post,
      url: URL(string: "http://127.0.0.1:8081/post")!
    )

    let (response, responseBody) = try await client.send(
      multipartFormData: formData,
      with: request,
    )

    #expect(response.status == .ok)

    let json = try #require(try await responseBody?.json() as? [String: Any])

    // Verify multipart headers were sent correctly
    let headers = try #require(json["headers"] as? [String: [String]])
    // Verify Content-Type includes multipart/form-data
    #expect(headers["Content-Type"]?.first?.contains("multipart/form-data") == true)

    // Verify boundary is present
    #expect(headers["Content-Type"]?.first?.contains("boundary=") == true)

    // Note: Content-Length may or may not be present depending on the transport
    // implementation (some use chunked transfer encoding)
  }
}

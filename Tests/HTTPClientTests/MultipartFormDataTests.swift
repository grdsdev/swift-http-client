import Foundation
import Testing

@testable import HTTPClient

@Suite
struct MultipartFormDataTests {
  @Test func multipartFormDataBoundaryGeneration() {
    let formData1 = MultipartFormData()
    let formData2 = MultipartFormData()

    // Boundaries should be unique
    #expect(formData1.boundary != formData2.boundary)

    // Custom boundary
    let customBoundary = "custom.boundary.123"
    let formData3 = MultipartFormData(boundary: customBoundary)
    #expect(formData3.boundary == customBoundary)
  }

  @Test func multipartFormDataContentType() {
    let formData = MultipartFormData(boundary: "test.boundary")
    #expect(formData.contentType == "multipart/form-data; boundary=test.boundary")
  }

  @Test func multipartFormDataAppendData() throws {
    let formData = MultipartFormData()
    let data = Data("Hello, World!".utf8)

    formData.append(data, withName: "message")
    #expect(formData.contentLength == UInt64(data.count))

    let encoded = try formData.encode()
    let encodedString = String(data: encoded, encoding: .utf8)!

    // Verify the encoded data contains the expected parts
    #expect(encodedString.contains("Content-Disposition: form-data; name=\"message\""))
    #expect(encodedString.contains("Hello, World!"))
  }

  @Test func multipartFormDataAppendDataWithFileName() throws {
    let formData = MultipartFormData()
    let data = Data("File content".utf8)

    formData.append(data, withName: "file", fileName: "test.txt", mimeType: "text/plain")

    let encoded = try formData.encode()
    let encodedString = String(data: encoded, encoding: .utf8)!

    #expect(
      encodedString.contains("Content-Disposition: form-data; name=\"file\"; filename=\"test.txt\"")
    )
    #expect(encodedString.contains("Content-Type: text/plain"))
    #expect(encodedString.contains("File content"))
  }

  @Test func multipartFormDataMultipleFields() throws {
    let formData = MultipartFormData()

    formData.append(Data("John Doe".utf8), withName: "name")
    formData.append(Data("john@example.com".utf8), withName: "email")
    formData.append(
      Data("Hello!".utf8), withName: "message", fileName: "message.txt", mimeType: "text/plain")

    let encoded = try formData.encode()
    let encodedString = String(data: encoded, encoding: .utf8)!

    // Verify all fields are present
    #expect(encodedString.contains("name=\"name\""))
    #expect(encodedString.contains("John Doe"))
    #expect(encodedString.contains("name=\"email\""))
    #expect(encodedString.contains("john@example.com"))
    #expect(encodedString.contains("name=\"message\""))
    #expect(encodedString.contains("Hello!"))

    // Verify boundaries are present
    #expect(encodedString.contains("--\(formData.boundary)"))
    #expect(encodedString.contains("--\(formData.boundary)--"))
  }

  @Test func multipartFormDataEncodeToFile() throws {
    let formData = MultipartFormData()
    let data1 = Data("First field".utf8)
    let data2 = Data("Second field".utf8)

    formData.append(data1, withName: "field1")
    formData.append(data2, withName: "field2")

    let tempURL = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
      .appendingPathExtension("multipart")

    try formData.writeEncodedData(to: tempURL)

    // Verify file was created
    #expect(FileManager.default.fileExists(atPath: tempURL.path))

    // Read and verify content
    let fileData = try Data(contentsOf: tempURL)
    let fileString = String(data: fileData, encoding: .utf8)!

    #expect(fileString.contains("field1"))
    #expect(fileString.contains("First field"))
    #expect(fileString.contains("field2"))
    #expect(fileString.contains("Second field"))

    // Clean up
    try? FileManager.default.removeItem(at: tempURL)
  }

  @Test func multipartFormDataAppendFile() throws {
    let formData = MultipartFormData()

    // Create a temporary file
    let tempURL = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
      .appendingPathExtension("txt")

    let fileContent = "This is a test file content"
    try Data(fileContent.utf8).write(to: tempURL)

    // Append the file
    formData.append(tempURL, withName: "upload")

    let encoded = try formData.encode()
    let encodedString = String(data: encoded, encoding: .utf8)!

    #expect(encodedString.contains("name=\"upload\""))
    #expect(encodedString.contains("filename"))
    #expect(encodedString.contains(fileContent))
    #expect(encodedString.contains("Content-Type:"))

    // Clean up
    try? FileManager.default.removeItem(at: tempURL)
  }

  @Test func multipartFormDataAppendFileWithCustomMimeType() throws {
    let formData = MultipartFormData()

    // Create a temporary file
    let tempURL = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
      .appendingPathExtension("json")

    let fileContent = "{\"key\": \"value\"}"
    try Data(fileContent.utf8).write(to: tempURL)

    // Append the file with custom name and mime type
    formData.append(
      tempURL, withName: "data", fileName: "custom.json", mimeType: "application/json")

    let encoded = try formData.encode()
    let encodedString = String(data: encoded, encoding: .utf8)!

    #expect(encodedString.contains("name=\"data\""))
    #expect(encodedString.contains("filename=\"custom.json\""))
    #expect(encodedString.contains("Content-Type: application/json"))
    #expect(encodedString.contains(fileContent))

    // Clean up
    try? FileManager.default.removeItem(at: tempURL)
  }

  @Test func multipartFormDataInvalidFileURLError() throws {
    let formData = MultipartFormData()
    let invalidURL = URL(string: "https://example.com/file.txt")!

    formData.append(invalidURL, withName: "file")

    // Should throw error when encoding
    #expect(throws: MultipartFormData.EncodingError.self) {
      try formData.encode()
    }
  }

  @Test func multipartFormDataFileAlreadyExistsError() throws {
    let formData = MultipartFormData()
    formData.append(Data("test".utf8), withName: "field")

    // Create a file at the destination
    let tempURL = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
      .appendingPathExtension("multipart")

    try Data().write(to: tempURL)

    // Should throw error when trying to write to existing file
    #expect(throws: MultipartFormData.EncodingError.self) {
      try formData.writeEncodedData(to: tempURL)
    }

    // Clean up
    try? FileManager.default.removeItem(at: tempURL)
  }

  @Test func multipartFormDataContentLength() {
    let formData = MultipartFormData()

    #expect(formData.contentLength == 0)

    formData.append(Data("Hello".utf8), withName: "message")
    #expect(formData.contentLength == 5)

    formData.append(Data("World".utf8), withName: "greeting")
    #expect(formData.contentLength == 10)
  }

  @Test func multipartFormDataBoundaryInEncodedData() throws {
    let boundary = "test.boundary.123"
    let formData = MultipartFormData(boundary: boundary)

    formData.append(Data("field1".utf8), withName: "name1")
    formData.append(Data("field2".utf8), withName: "name2")

    let encoded = try formData.encode()
    let encodedString = String(data: encoded, encoding: .utf8)!

    // Check for initial boundary
    #expect(encodedString.hasPrefix("--\(boundary)\r\n"))

    // Check for encapsulated boundary between fields
    #expect(encodedString.contains("\r\n--\(boundary)\r\n"))

    // Check for final boundary
    #expect(encodedString.hasSuffix("\r\n--\(boundary)--\r\n"))
  }

  @Test func multipartFormDataEmptyEncode() throws {
    let formData = MultipartFormData()

    let encoded = try formData.encode()

    // Empty multipart form data should have no boundaries
    #expect(encoded.isEmpty)
  }

  @Test func multipartFormDataInputStream() throws {
    let formData = MultipartFormData()
    let testData = Data("Stream test data".utf8)
    let stream = InputStream(data: testData)

    formData.append(
      stream,
      withLength: UInt64(testData.count),
      name: "stream_field",
      fileName: "stream.txt",
      mimeType: "text/plain"
    )

    let encoded = try formData.encode()
    let encodedString = String(data: encoded, encoding: .utf8)!

    #expect(encodedString.contains("name=\"stream_field\""))
    #expect(encodedString.contains("filename=\"stream.txt\""))
    #expect(encodedString.contains("Content-Type: text/plain"))
    #expect(encodedString.contains("Stream test data"))
  }
}

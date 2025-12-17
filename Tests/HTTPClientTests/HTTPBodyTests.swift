import Foundation
import Testing

@testable import HTTPClient

@Suite
struct HTTPBodyTests {

  // MARK: - Creation Tests

  @Test func createEmptyBody() {
    let body = HTTPBody()
    #expect(body.length == .known(0))
    #expect(body.iterationBehavior == .multiple)
  }

  @Test func createBodyFromByteChunk() {
    let bytes: HTTPBody.ByteChunk = [1, 2, 3, 4, 5]
    let body = HTTPBody(bytes)
    #expect(body.length == .known(5))
    #expect(body.iterationBehavior == .multiple)
  }

  @Test func createBodyFromData() {
    let data = Data("Hello".utf8)
    let body = HTTPBody(data)
    #expect(body.length == .known(5))
  }

  @Test func createBodyFromString() {
    let body = HTTPBody("Test")
    #expect(body.length == .known(4))
  }

  @Test func createBodyFromStringLiteral() {
    let body: HTTPBody = "Literal"
    #expect(body.length == .known(7))
  }

  @Test func createBodyFromArray() {
    let bytes: [UInt8] = [72, 101, 108, 108, 111]  // "Hello"
    let body = HTTPBody(bytes)
    #expect(body.length == .known(5))
  }

  @Test func createBodyFromArrayLiteral() {
    let body: HTTPBody = [72, 101, 108, 108, 111]
    #expect(body.length == .known(5))
  }

  @Test func createBodyWithKnownLength() {
    let bytes: HTTPBody.ByteChunk = [1, 2, 3]
    let body = HTTPBody(bytes, length: .known(10))
    #expect(body.length == .known(10))
  }

  @Test func createBodyWithUnknownLength() {
    let bytes: HTTPBody.ByteChunk = [1, 2, 3]
    let body = HTTPBody(bytes, length: .unknown)
    #expect(body.length == .unknown)
  }

  @Test func createBodyFromAsyncStream() {
    let stream = AsyncStream<HTTPBody.ByteChunk> { continuation in
      continuation.yield([1, 2, 3])
      continuation.finish()
    }
    let body = HTTPBody(stream, length: .known(3))
    #expect(body.length == .known(3))
    #expect(body.iterationBehavior == .single)
  }

  @Test func createBodyFromAsyncThrowingStream() {
    let stream = AsyncThrowingStream<HTTPBody.ByteChunk, Error> { continuation in
      continuation.yield([1, 2, 3])
      continuation.finish()
    }
    let body = HTTPBody(stream, length: .unknown)
    #expect(body.length == .unknown)
    #expect(body.iterationBehavior == .single)
  }

  // MARK: - Iteration Behavior Tests

  @Test func singleIterationBehavior() async throws {
    let stream = AsyncStream<HTTPBody.ByteChunk> { continuation in
      continuation.yield([1, 2, 3])
      continuation.finish()
    }
    let body = HTTPBody(stream, length: .known(3))

    // First iteration should succeed
    var chunks: [HTTPBody.ByteChunk] = []
    for try await chunk in body {
      chunks.append(chunk)
    }
    #expect(chunks.count == 1)

    // Second iteration should fail
    var secondIterationFailed = false
    do {
      for try await _ in body {
        // Should not reach here
      }
    } catch {
      secondIterationFailed = true
    }
    #expect(secondIterationFailed)
  }

  @Test func multipleIterationBehavior() async throws {
    let chunks: [HTTPBody.ByteChunk] = [[1, 2], [3, 4]]
    let body = HTTPBody(chunks, length: .known(4), iterationBehavior: .multiple)

    // First iteration
    var firstChunks: [HTTPBody.ByteChunk] = []
    for try await chunk in body {
      firstChunks.append(chunk)
    }
    #expect(firstChunks.count == 2)

    // Second iteration should also succeed
    var secondChunks: [HTTPBody.ByteChunk] = []
    for try await chunk in body {
      secondChunks.append(chunk)
    }
    #expect(secondChunks.count == 2)
  }

  // MARK: - Collecting Tests

  @Test func collectBodyToByteChunk() async throws {
    let body = HTTPBody("Hello, World!")
    let collected = try await HTTPBody.ByteChunk(collecting: body, upTo: 1024)
    #expect(collected.count == 13)
    #expect(String(decoding: collected, as: UTF8.self) == "Hello, World!")
  }

  @Test func collectBodyToArray() async throws {
    let body = HTTPBody([1, 2, 3, 4, 5])
    let collected = try await [UInt8](collecting: body, upTo: 1024)
    #expect(collected == [1, 2, 3, 4, 5])
  }

  @Test func collectBodyToString() async throws {
    let body = HTTPBody("Swift HTTP Client")
    let collected = try await String(collecting: body, upTo: 1024)
    #expect(collected == "Swift HTTP Client")
  }

  @Test func collectBodyToData() async throws {
    let originalData = Data("Test Data".utf8)
    let body = HTTPBody(originalData)
    let collected = try await Data(collecting: body, upTo: 1024)
    #expect(collected == originalData)
  }

  @Test func collectBodyExceedingMaxBytes() async throws {
    let body = HTTPBody("This is a long string that exceeds the limit")

    var didThrow = false
    do {
      _ = try await String(collecting: body, upTo: 10)
    } catch {
      didThrow = true
    }
    #expect(didThrow)
  }

  @Test func collectBodyWithKnownLengthExceedingMax() async throws {
    let body = HTTPBody("Long content", length: .known(100))

    var didThrow = false
    do {
      _ = try await String(collecting: body, upTo: 10)
    } catch {
      didThrow = true
    }
    #expect(didThrow)
  }

  @Test func collectEmptyBody() async throws {
    let body = HTTPBody()
    let collected = try await String(collecting: body, upTo: 1024)
    #expect(collected.isEmpty)
  }

  @Test func collectBodyWithMultipleChunks() async throws {
    let chunks: [HTTPBody.ByteChunk] = [
      Array("Hello, ".utf8)[...],
      Array("World".utf8)[...],
      Array("!".utf8)[...],
    ]
    let body = HTTPBody(chunks, length: .known(13), iterationBehavior: .multiple)
    let collected = try await String(collecting: body, upTo: 1024)
    #expect(collected == "Hello, World!")
  }

  // MARK: - AsyncSequence Tests

  @Test func iterateOverBodyChunks() async throws {
    let chunks: [HTTPBody.ByteChunk] = [
      [1, 2],
      [3, 4],
      [5, 6],
    ]
    let body = HTTPBody(chunks, length: .known(6), iterationBehavior: .multiple)

    var collectedChunks: [HTTPBody.ByteChunk] = []
    for try await chunk in body {
      collectedChunks.append(chunk)
    }

    #expect(collectedChunks.count == 3)
    #expect(Array(collectedChunks[0]) == [1, 2])
    #expect(Array(collectedChunks[1]) == [3, 4])
    #expect(Array(collectedChunks[2]) == [5, 6])
  }

  @Test func mapBodyChunks() async throws {
    let body = HTTPBody("Test")
    let sizes = body.map { $0.count }

    var collectedSizes: [Int] = []
    for try await size in sizes {
      collectedSizes.append(size)
    }

    #expect(collectedSizes.count == 1)
    #expect(collectedSizes[0] == 4)
  }

  @Test func filterBodyChunks() async throws {
    let chunks: [HTTPBody.ByteChunk] = [
      [1, 2],
      [3, 4, 5],
      [6],
    ]
    let body = HTTPBody(chunks, length: .known(6), iterationBehavior: .multiple)
    let filtered = body.filter { $0.count > 1 }

    var collectedChunks: [HTTPBody.ByteChunk] = []
    for try await chunk in filtered {
      collectedChunks.append(chunk)
    }

    #expect(collectedChunks.count == 2)
  }

  // MARK: - Equality and Hashing Tests

  @Test func bodyEqualityByIdentity() {
    let body1 = HTTPBody("Test")
    let body2 = body1
    let body3 = HTTPBody("Test")

    #expect(body1 == body2)  // Same instance
    #expect(body1 != body3)  // Different instances
  }

  @Test func bodyHashable() {
    let body1 = HTTPBody("Test")
    let body2 = body1
    let body3 = HTTPBody("Test")

    var set = Set<HTTPBody>()
    set.insert(body1)
    set.insert(body2)
    set.insert(body3)

    // body1 and body2 are the same instance, body3 is different
    #expect(set.count == 2)
  }

  // MARK: - Length Tests

  @Test func lengthEquality() {
    #expect(HTTPBody.Length.unknown == .unknown)
    #expect(HTTPBody.Length.known(100) == .known(100))
    #expect(HTTPBody.Length.known(100) != .known(200))
    #expect(HTTPBody.Length.known(100) != .unknown)
  }

  // MARK: - Edge Cases

  @Test func bodyWithZeroLengthChunks() async throws {
    let chunks: [HTTPBody.ByteChunk] = [
      [],
      [1, 2, 3],
      [],
    ]
    let body = HTTPBody(chunks, length: .known(3), iterationBehavior: .multiple)

    var chunkCount = 0
    for try await _ in body {
      chunkCount += 1
    }

    #expect(chunkCount == 3)
  }

  @Test func bodyWithLargeContent() async throws {
    let largeData = Data(repeating: 65, count: 100_000)  // 100KB of 'A's
    let body = HTTPBody(largeData)

    let collected = try await Data(collecting: body, upTo: 200_000)
    #expect(collected.count == 100_000)
  }

  @Test func bodyFromAsyncSequenceOfStrings() async throws {
    let stream = AsyncStream<String> { continuation in
      continuation.yield("Hello")
      continuation.yield(" ")
      continuation.yield("World")
      continuation.finish()
    }

    let body = HTTPBody(stream, length: .known(11), iterationBehavior: .single)
    let collected = try await String(collecting: body, upTo: 1024)

    #expect(collected == "Hello World")
  }

  @Test func bodyIteratorCreatedFlag() {
    let body = HTTPBody("Test")

    // Before iteration
    #expect(body.testing_iteratorCreated == false)

    // This would require async iteration to test properly
    // The flag is checked in makeAsyncIterator()
  }

  @Test func emptyBodyCollecting() async throws {
    let body = HTTPBody()

    let asBytes = try await [UInt8](collecting: body, upTo: 1024)
    #expect(asBytes.isEmpty)

    let asString = try await String(collecting: body, upTo: 1024)
    #expect(asString.isEmpty)

    let asData = try await Data(collecting: body, upTo: 1024)
    #expect(asData.isEmpty)
  }

  @Test func bodyWithCustomLength() {
    let body = HTTPBody("Short", length: .known(100))
    #expect(body.length == .known(100))  // Length can be different from actual content
  }

  @Test func bodyFromByteSequence() async throws {
    let bytes = [UInt8](repeating: 65, count: 5)  // "AAAAA"
    let body = HTTPBody(bytes)

    let collected = try await String(collecting: body, upTo: 1024)
    #expect(collected == "AAAAA")
  }
}

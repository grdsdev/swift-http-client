import Foundation
import Testing

@testable import HTTPClient

@Suite
struct HTTPBodyProgressTests {

  // Disambiguate from Foundation.Progress
  typealias Progress = HTTPClient.Progress

  // MARK: - Progress struct tests

  @Test func progressInitialization() {
    let progress = Progress(completed: 100, total: 200)
    #expect(progress.completed == 100)
    #expect(progress.total == 200)
  }

  @Test func progressWithUnknownTotal() {
    let progress = Progress(completed: 50, total: nil)
    #expect(progress.completed == 50)
    #expect(progress.total == nil)
  }

  @Test func progressFractionCompletedKnownTotal() {
    let progress = Progress(completed: 50, total: 100)
    #expect(progress.fractionCompleted == 0.5)
  }

  @Test func progressFractionCompletedFullyComplete() {
    let progress = Progress(completed: 100, total: 100)
    #expect(progress.fractionCompleted == 1.0)
  }

  @Test func progressFractionCompletedZeroCompleted() {
    let progress = Progress(completed: 0, total: 100)
    #expect(progress.fractionCompleted == 0.0)
  }

  @Test func progressFractionCompletedUnknownTotal() {
    let progress = Progress(completed: 50, total: nil)
    #expect(progress.fractionCompleted == nil)
  }

  @Test func progressFractionCompletedZeroTotal() {
    let progress = Progress(completed: 0, total: 0)
    #expect(progress.fractionCompleted == nil)
  }

  @Test func progressEquality() {
    let progress1 = Progress(completed: 50, total: 100)
    let progress2 = Progress(completed: 50, total: 100)
    let progress3 = Progress(completed: 51, total: 100)

    #expect(progress1 == progress2)
    #expect(progress1 != progress3)
  }

  @Test func progressHashable() {
    let progress1 = Progress(completed: 50, total: 100)
    let progress2 = Progress(completed: 50, total: 100)

    var set = Set<Progress>()
    set.insert(progress1)
    set.insert(progress2)

    // Same progress values should result in one element
    #expect(set.count == 1)
  }

  // MARK: - trackingProgress tests

  @Test func trackingProgressWithSingleChunk() async throws {
    let data = Data("Hello, World!".utf8)
    let body = HTTPBody(data)

    let progressUpdates = SendableBox<[Progress]>([])
    let trackedBody = body.trackingProgress { progress in
      progressUpdates.withLock { $0.append(progress) }
    }

    // Consume the body
    for try await _ in trackedBody {}

    let updates = progressUpdates.value
    #expect(updates.count == 1)
    #expect(updates[0].completed == 13)
    #expect(updates[0].total == 13)
    #expect(updates[0].fractionCompleted == 1.0)
  }

  @Test func trackingProgressWithMultipleChunks() async throws {
    let chunks: [HTTPBody.ByteChunk] = [
      Array("Hello".utf8)[...],
      Array(", ".utf8)[...],
      Array("World!".utf8)[...],
    ]
    let body = HTTPBody(chunks, length: .known(13), iterationBehavior: .multiple)

    let progressUpdates = SendableBox<[Progress]>([])
    let trackedBody = body.trackingProgress { progress in
      progressUpdates.withLock { $0.append(progress) }
    }

    // Consume the body
    for try await _ in trackedBody {}

    let updates = progressUpdates.value
    #expect(updates.count == 3)

    // First chunk: "Hello" (5 bytes)
    #expect(updates[0].completed == 5)
    #expect(updates[0].total == 13)
    #expect(updates[0].fractionCompleted == 5.0 / 13.0)

    // Second chunk: ", " (2 bytes, cumulative 7)
    #expect(updates[1].completed == 7)
    #expect(updates[1].total == 13)
    #expect(updates[1].fractionCompleted == 7.0 / 13.0)

    // Third chunk: "World!" (6 bytes, cumulative 13)
    #expect(updates[2].completed == 13)
    #expect(updates[2].total == 13)
    #expect(updates[2].fractionCompleted == 1.0)
  }

  @Test func trackingProgressWithUnknownLength() async throws {
    let chunks: [HTTPBody.ByteChunk] = [
      Array("Part1".utf8)[...],
      Array("Part2".utf8)[...],
    ]
    let body = HTTPBody(chunks, length: .unknown, iterationBehavior: .multiple)

    let progressUpdates = SendableBox<[Progress]>([])
    let trackedBody = body.trackingProgress { progress in
      progressUpdates.withLock { $0.append(progress) }
    }

    // Consume the body
    for try await _ in trackedBody {}

    let updates = progressUpdates.value
    #expect(updates.count == 2)

    // First chunk
    #expect(updates[0].completed == 5)
    #expect(updates[0].total == nil)
    #expect(updates[0].fractionCompleted == nil)

    // Second chunk
    #expect(updates[1].completed == 10)
    #expect(updates[1].total == nil)
    #expect(updates[1].fractionCompleted == nil)
  }

  @Test func trackingProgressWithEmptyBody() async throws {
    let body = HTTPBody()

    let progressUpdates = SendableBox<[Progress]>([])
    let trackedBody = body.trackingProgress { progress in
      progressUpdates.withLock { $0.append(progress) }
    }

    // Consume the body
    for try await _ in trackedBody {}

    // No chunks, so no progress updates
    #expect(progressUpdates.value.isEmpty)
  }

  @Test func trackingProgressPreservesBodyLength() {
    let body = HTTPBody("Test", length: .known(4))
    let trackedBody = body.trackingProgress { _ in }

    #expect(trackedBody.length == .known(4))
  }

  @Test func trackingProgressPreservesUnknownLength() {
    let chunks: [HTTPBody.ByteChunk] = [Array("Test".utf8)[...]]
    let body = HTTPBody(chunks, length: .unknown, iterationBehavior: .multiple)
    let trackedBody = body.trackingProgress { _ in }

    #expect(trackedBody.length == .unknown)
  }

  @Test func trackingProgressPreservesIterationBehavior() {
    let body = HTTPBody("Test", length: .known(4))
    let trackedBody = body.trackingProgress { _ in }

    #expect(trackedBody.iterationBehavior == body.iterationBehavior)
  }

  @Test func trackingProgressWithLargeData() async throws {
    // Create a larger body with multiple chunks
    let chunkSize = 1024
    let numChunks = 10
    var chunks: [HTTPBody.ByteChunk] = []

    for _ in 0..<numChunks {
      let bytes = Array(repeating: UInt8(65), count: chunkSize)  // 'A' character
      chunks.append(bytes[...])
    }

    let totalSize = Int64(chunkSize * numChunks)
    let body = HTTPBody(chunks, length: .known(totalSize), iterationBehavior: .multiple)

    let progressUpdates = SendableBox<[Progress]>([])
    let trackedBody = body.trackingProgress { progress in
      progressUpdates.withLock { $0.append(progress) }
    }

    // Consume the body
    for try await _ in trackedBody {}

    let updates = progressUpdates.value
    #expect(updates.count == numChunks)

    // Verify cumulative progress
    for (index, progress) in updates.enumerated() {
      let expectedCompleted = Int64(chunkSize * (index + 1))
      #expect(progress.completed == expectedCompleted)
      #expect(progress.total == totalSize)

      let expectedFraction = Double(expectedCompleted) / Double(totalSize)
      #expect(progress.fractionCompleted == expectedFraction)
    }

    // Last update should be 100% complete
    #expect(updates.last?.fractionCompleted == 1.0)
  }

  @Test func trackingProgressWithAsyncStream() async throws {
    let chunks = ["Hello", " ", "World!"]

    let stream = AsyncStream<HTTPBody.ByteChunk> { continuation in
      for chunk in chunks {
        continuation.yield(Array(chunk.utf8)[...])
      }
      continuation.finish()
    }

    let totalLength = chunks.joined().count
    let body = HTTPBody(stream, length: .known(Int64(totalLength)))

    let progressUpdates = SendableBox<[Progress]>([])
    let trackedBody = body.trackingProgress { progress in
      progressUpdates.withLock { $0.append(progress) }
    }

    // Consume the body
    for try await _ in trackedBody {}

    let updates = progressUpdates.value
    #expect(updates.count == 3)
    #expect(updates.last?.completed == Int64(totalLength))
  }

  @Test func trackingProgressHandlerCalledInOrder() async throws {
    let chunks: [HTTPBody.ByteChunk] = [
      Array("1".utf8)[...],
      Array("2".utf8)[...],
      Array("3".utf8)[...],
    ]
    let body = HTTPBody(chunks, length: .known(3), iterationBehavior: .multiple)

    let completedValues = SendableBox<[Int64]>([])
    let trackedBody = body.trackingProgress { progress in
      completedValues.withLock { $0.append(progress.completed) }
    }

    // Consume the body
    for try await _ in trackedBody {}

    // Verify progress is monotonically increasing
    #expect(completedValues.value == [1, 2, 3])
  }

  @Test func trackingProgressDoesNotModifyChunks() async throws {
    let originalData = "Test Data"
    let body = HTTPBody(originalData)

    let trackedBody = body.trackingProgress { _ in }

    // Consume and collect the data
    let collectedData = try await String(collecting: trackedBody, upTo: 1024)

    #expect(collectedData == originalData)
  }

  @Test func trackingProgressMultipleIterations() async throws {
    let chunks: [HTTPBody.ByteChunk] = [
      Array("AB".utf8)[...],
      Array("CD".utf8)[...],
    ]
    let body = HTTPBody(chunks, length: .known(4), iterationBehavior: .multiple)

    let firstUpdates = SendableBox<[Progress]>([])
    let trackedBody = body.trackingProgress { progress in
      firstUpdates.withLock { $0.append(progress) }
    }

    // First iteration
    for try await _ in trackedBody {}

    #expect(firstUpdates.value.count == 2)

    // Note: Second iteration would create a new tracked body
    // as trackingProgress returns a new HTTPBody instance
    let secondUpdates = SendableBox<[Progress]>([])
    let trackedBody2 = body.trackingProgress { progress in
      secondUpdates.withLock { $0.append(progress) }
    }

    // Second iteration
    for try await _ in trackedBody2 {}

    #expect(secondUpdates.value.count == 2)
  }

  @Test func progressFractionCompletedEdgeCases() {
    // Test with very large numbers
    let largeProgress = Progress(completed: Int64.max - 1, total: Int64.max)
    #expect(largeProgress.fractionCompleted != nil)

    // Test with small total
    let smallProgress = Progress(completed: 1, total: 2)
    #expect(smallProgress.fractionCompleted == 0.5)
  }

  @Test func trackingProgressWithZeroSizedChunks() async throws {
    let chunks: [HTTPBody.ByteChunk] = [
      Array("".utf8)[...],
      Array("Hello".utf8)[...],
      Array("".utf8)[...],
    ]
    let body = HTTPBody(chunks, length: .known(5), iterationBehavior: .multiple)

    let progressUpdates = SendableBox<[Progress]>([])
    let trackedBody = body.trackingProgress { progress in
      progressUpdates.withLock { $0.append(progress) }
    }

    // Consume the body
    for try await _ in trackedBody {}

    // Should have 3 updates (one for each chunk, even zero-sized ones)
    let updates = progressUpdates.value
    #expect(updates.count == 3)
    #expect(updates[0].completed == 0)  // Empty chunk
    #expect(updates[1].completed == 5)  // "Hello"
    #expect(updates[2].completed == 5)  // Empty chunk (no change)
  }
}

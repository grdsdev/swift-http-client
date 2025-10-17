# HTTPClient Tests

This directory contains comprehensive tests for the HTTPClient library, including unit tests and integration tests.

## Test Suites

### 1. HTTPClientTests.swift
Basic integration test demonstrating client usage.

**Tests**: 1
- Basic HTTP GET request

### 2. MultipartFormDataTests.swift
Unit tests for the MultipartFormData implementation.

**Tests**: 14
- Boundary generation and validation
- Content-Type header generation
- Data appending (raw data, files, streams)
- Multiple field handling
- In-memory encoding
- Disk-based encoding
- Error handling
- Edge cases (empty data, invalid URLs, file existence)

**Run**: `swift test --filter MultipartFormDataTests`

### 3. MultipartFormDataIntegrationTests.swift
Integration tests for HTTPBody and HTTPRequest integration with MultipartFormData.

**Tests**: 7
- In-memory encoding integration
- Disk-based encoding integration
- Automatic encoding strategy
- HTTPRequest creation
- Custom headers
- File streaming from disk
- Error handling for invalid URLs

**Run**: `swift test --filter MultipartFormDataIntegrationTests`

### 4. MultipartFormDataHTTPBinTests.swift
End-to-end integration tests using the httpbin.org testing API.

**Tests**: 11
- Simple form data upload
- File data upload
- Multiple files upload
- Custom headers
- Large data upload (500KB)
- Actual file from disk upload
- Disk-based streaming
- Minimal/empty form data
- Binary data upload
- Special characters (Unicode, emojis)
- Multipart headers verification

**Run**: `swift test --filter MultipartFormDataHTTPBinTests`

**Note**: These tests require internet connectivity and will make real HTTP requests to httpbin.org.

## Running Tests

### Run All Tests
```bash
swift test
```

### Run Specific Test Suite
```bash
swift test --filter MultipartFormDataTests
swift test --filter MultipartFormDataIntegrationTests
swift test --filter MultipartFormDataHTTPBinTests
```

### Run Single Test
```bash
swift test --filter uploadSimpleFormDataToHTTPBin
```

### Run Tests Without Network Calls
```bash
# Run only unit tests (no network)
swift test --filter MultipartFormDataTests
swift test --filter MultipartFormDataIntegrationTests
```

## Test Coverage

### Multipart Form Data Functionality

| Feature | Unit Tests | Integration Tests | HTTPBin Tests |
|---------|------------|-------------------|---------------|
| Boundary generation | ✅ | ✅ | ✅ |
| Content-Type header | ✅ | ✅ | ✅ |
| Form field appending | ✅ | ✅ | ✅ |
| File appending | ✅ | ✅ | ✅ |
| Multiple files | ✅ | ✅ | ✅ |
| In-memory encoding | ✅ | ✅ | ✅ |
| Disk-based encoding | ✅ | ✅ | ✅ |
| Automatic encoding | ✅ | ✅ | ✅ |
| Custom headers | ✅ | ✅ | ✅ |
| Binary data | ✅ | - | ✅ |
| Unicode/Special chars | ✅ | - | ✅ |
| Error handling | ✅ | ✅ | - |
| Streaming from disk | - | ✅ | ✅ |
| Large files (>10MB) | ✅ | ✅ | - |

## HTTPBin.org API

The integration tests use [httpbin.org](https://httpbin.org), a free HTTP testing service.

### Key Endpoints Used

- **POST /post**: Accepts POST requests and returns JSON containing:
  - `form`: Form fields as key-value pairs
  - `files`: Uploaded files with their content
  - `headers`: HTTP headers sent in the request
  - `json`: JSON data if sent

### Example Response
```json
{
  "args": {},
  "data": "",
  "files": {
    "file": "file content here"
  },
  "form": {
    "name": "John Doe",
    "email": "john@example.com"
  },
  "headers": {
    "Content-Type": "multipart/form-data; boundary=...",
    "Content-Length": "1234",
    "User-Agent": "..."
  },
  "json": null,
  "origin": "...",
  "url": "https://httpbin.org/post"
}
```

## Test Characteristics

### Fast Tests (< 100ms)
- All unit tests in `MultipartFormDataTests`
- Most tests in `MultipartFormDataIntegrationTests`

### Slow Tests (1-5 seconds)
- All tests in `MultipartFormDataHTTPBinTests` (network latency)

### Very Slow Tests (> 5 seconds)
- `uploadLargeDataToHTTPBin` (uploads 500KB)
- Tests with disk I/O

## Continuous Integration

For CI environments, you may want to:

1. **Run unit tests first** (fast feedback):
   ```bash
   swift test --filter MultipartFormDataTests
   ```

2. **Run integration tests** (if unit tests pass):
   ```bash
   swift test --filter MultipartFormDataIntegrationTests
   ```

3. **Run HTTPBin tests** (optional, requires network):
   ```bash
   swift test --filter MultipartFormDataHTTPBinTests
   ```

## Known Issues

### Empty Form Data
Sending completely empty multipart form data (no fields at all) causes a crash in the underlying URLSession transport layer. This is a limitation of the transport implementation, not the multipart encoding.

**Workaround**: Always include at least one field, even if empty:
```swift
formData.append(Data("".utf8), withName: "placeholder")
```

### Content-Length Header
Some tests verify the presence of the `Content-Length` header. However, depending on the transport implementation and HTTP version, this header may be:
- Set automatically by URLSession
- Replaced with chunked transfer encoding
- Not echoed back by the server

The tests have been updated to be lenient about this.

## Adding New Tests

When adding new tests:

1. **Unit tests** should go in `MultipartFormDataTests.swift`
   - Test individual functions
   - No network calls
   - Fast execution

2. **Integration tests** should go in `MultipartFormDataIntegrationTests.swift`
   - Test interaction between components
   - No external network calls
   - Mock/stub external dependencies

3. **E2E tests** should go in `MultipartFormDataHTTPBinTests.swift`
   - Test complete workflows
   - Real HTTP calls to httpbin.org
   - Verify actual server responses

## Test Results

All tests pass ✅

```
Test run with 33 tests in 0 suites passed after 5.336 seconds.
```

Breakdown:
- 1 basic HTTP test
- 14 multipart unit tests
- 7 multipart integration tests
- 11 HTTPBin integration tests

## Performance

Typical test execution times:
- Unit tests: ~0.05 seconds
- Integration tests: ~0.05 seconds
- HTTPBin tests: ~5 seconds (network dependent)
- **Total**: ~5-10 seconds

## Troubleshooting

### Tests Fail Due to Network Issues
If HTTPBin tests fail:
1. Check internet connectivity
2. Verify httpbin.org is accessible: `curl https://httpbin.org/get`
3. Run only unit tests: `swift test --filter MultipartFormDataTests`

### Tests Timeout
Increase timeout in test configuration or run specific test suites separately.

### Flaky Tests
HTTPBin tests may be flaky due to network issues. If a test fails:
1. Re-run the specific test
2. Check httpbin.org status
3. Verify network conditions

## Future Improvements

Potential additions:
- [ ] Progress tracking tests (when middleware is added)
- [ ] Retry logic tests
- [ ] Authentication tests with real services
- [ ] Performance benchmarks
- [ ] Memory usage tests for large files
- [ ] Concurrent upload tests
- [ ] Cancellation tests

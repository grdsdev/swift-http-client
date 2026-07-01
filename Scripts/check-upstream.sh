#!/usr/bin/env bash
# Compares upstream swift-openapi-runtime and swift-openapi-urlsession files
# against their local counterparts, ignoring indentation-only differences.
#
# Usage: ./Scripts/check-upstream.sh
# Requires: gh (GitHub CLI), base64, diff

set -euo pipefail

TMPDIR_LOCAL=$(mktemp -d)
trap 'rm -rf "$TMPDIR_LOCAL"' EXIT

SOURCES="Sources/HTTPClient"

fetch() {
  local repo="$1" remote_path="$2" local_path="$3" label="$4"
  local upstream="$TMPDIR_LOCAL/$(basename "$remote_path")"
  gh api "repos/$repo/contents/$remote_path" --jq '.content' | base64 -d > "$upstream"

  # Strip import lines that differ only due to module name (OpenAPIRuntime vs HTTPTypes)
  # and do an ignore-whitespace diff to surface only logic changes
  if ! diff --ignore-all-space --ignore-blank-lines "$upstream" "$local_path" > /dev/null 2>&1; then
    echo "=== $label ==="
    diff --ignore-all-space --ignore-blank-lines "$upstream" "$local_path" || true
    echo ""
  else
    echo "[ok] $label"
  fi
}

echo "Checking swift-openapi-runtime files..."
fetch apple/swift-openapi-runtime \
  Sources/OpenAPIRuntime/Interface/HTTPBody.swift \
  "$SOURCES/Interface/HTTPBody.swift" \
  "HTTPBody.swift"

fetch apple/swift-openapi-runtime \
  Sources/OpenAPIRuntime/Interface/AsyncSequenceCommon.swift \
  "$SOURCES/Interface/AsyncSequenceCommon.swift" \
  "AsyncSequenceCommon.swift"

fetch apple/swift-openapi-runtime \
  Sources/OpenAPIRuntime/Interface/ClientTransport.swift \
  "$SOURCES/Interface/ClientTransport.swift" \
  "ClientTransport.swift"

fetch apple/swift-openapi-runtime \
  Sources/OpenAPIRuntime/Interface/CurrencyTypes.swift \
  "$SOURCES/Interface/CurrencyTypes.swift" \
  "CurrencyTypes.swift"

fetch apple/swift-openapi-runtime \
  Sources/OpenAPIRuntime/Errors/ClientError.swift \
  "$SOURCES/Errors/ClientError.swift" \
  "ClientError.swift"

fetch apple/swift-openapi-runtime \
  Sources/OpenAPIRuntime/Errors/RuntimeError.swift \
  "$SOURCES/Errors/RuntimeError.swift" \
  "RuntimeError.swift"

fetch apple/swift-openapi-runtime \
  Sources/OpenAPIRuntime/Base/PrettyStringConvertible.swift \
  "$SOURCES/Base/PrettyStringConvertible.swift" \
  "PrettyStringConvertible.swift"

echo ""
echo "Checking swift-openapi-urlsession files..."

fetch apple/swift-openapi-urlsession \
  Sources/OpenAPIURLSession/URLSessionTransport.swift \
  "$SOURCES/HTTPClientFoundation/URLSessionTransport.swift" \
  "URLSessionTransport.swift"

fetch apple/swift-openapi-urlsession \
  Sources/OpenAPIURLSession/BufferedStream/BufferedStream.swift \
  "$SOURCES/HTTPClientFoundation/BufferedStream/BufferedStream.swift" \
  "BufferedStream.swift"

fetch apple/swift-openapi-urlsession \
  Sources/OpenAPIURLSession/BufferedStream/Lock.swift \
  "$SOURCES/HTTPClientFoundation/BufferedStream/Lock.swift" \
  "Lock.swift"

fetch apple/swift-openapi-urlsession \
  Sources/OpenAPIURLSession/URLSessionBidirectionalStreaming/BidirectionalStreamingURLSessionDelegate.swift \
  "$SOURCES/HTTPClientFoundation/URLSessionBidirectionalStreaming/BidirectionalStreamingURLSessionDelegate.swift" \
  "BidirectionalStreamingURLSessionDelegate.swift"

fetch apple/swift-openapi-urlsession \
  Sources/OpenAPIURLSession/URLSessionBidirectionalStreaming/HTTPBodyOutputStreamBridge.swift \
  "$SOURCES/HTTPClientFoundation/URLSessionBidirectionalStreaming/HTTPBodyOutputStreamBridge.swift" \
  "HTTPBodyOutputStreamBridge.swift"

fetch apple/swift-openapi-urlsession \
  Sources/OpenAPIURLSession/URLSessionBidirectionalStreaming/URLSession+Extensions.swift \
  "$SOURCES/HTTPClientFoundation/URLSessionBidirectionalStreaming/URLSession+Extensions.swift" \
  "URLSession+Extensions.swift"

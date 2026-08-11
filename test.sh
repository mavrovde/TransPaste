#!/bin/bash
# Compiles and runs the full test suite. Works with Command Line Tools only
# (no Xcode/XCTest required — see Tests/TestKit.swift).
#
# Usage:
#   ./test.sh              # run all tests
#   ./test.sh "API key"    # run only tests whose name matches the filter
set -euo pipefail
cd "$(dirname "$0")"

BUILD_DIR="build/tests"
TEST_BIN="${BUILD_DIR}/transpaste-tests"

mkdir -p "${BUILD_DIR}"

echo "Building tests..."
# Sources/main.swift is excluded: its top-level code would conflict with the
# test runner's @main entry point.
swiftc \
    Sources/AppDelegate.swift \
    Sources/GoogleGeminiService.swift \
    Sources/InputMonitor.swift \
    Sources/Logger.swift \
    Tests/*.swift \
    -o "${TEST_BIN}"

echo "Running tests..."
"${TEST_BIN}" "$@"

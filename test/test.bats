#!/usr/bin/env bats

# Aqua Security Scanner (Trivy Premium) MVP Test Suite
# Tests core functionality with real Aqua Premium Scanner

setup_file() {
  # Check Docker is running
  if ! docker info >/dev/null 2>&1; then
    echo "Docker is not running" >&2
    return 1
  fi

  # Check entrypoint.sh exists
  if [ ! -f "./entrypoint.sh" ]; then
    echo "entrypoint.sh not found" >&2
    return 1
  fi
}

setup() {
  # Load BATS libraries
  load "${BATS_LIB_PATH}/bats-support/load"
  load "${BATS_LIB_PATH}/bats-assert/load"
  load "${BATS_LIB_PATH}/bats-file/load"

  # Export Aqua credentials (required for all tests)
  export AQUA_SERVER="${AQUA_SERVER:-https://console.cloud.aquasec.com}"
  export AQUA_TOKEN="${AQUA_TOKEN}"
  export SCANNER_VERSION="${SCANNER_VERSION:-saas-latest}"

  # Scanner requires GitHub workspace
  export GITHUB_WORKSPACE="$(pwd)"
}

teardown() {
  # Clean up test output files
  rm -f test-output.* || true
  rm -f results.json || true
  rm -f results.sarif || true

  # Reset environment variables
  unset INPUT_SCAN_REF
  unset INPUT_FORMAT
  unset INPUT_OUTPUT
  unset IMAGE_REGISTRY_INTEGRATION
  unset REGISTER_COMPLIANT
  unset SCAN_LOCAL
}

# Helper function to strip environment-dependent fields from JSON
strip_json_fields() {
  local file="$1"
  # Remove timestamps and version-specific fields
  sed -E '/"CreatedAt":/d; /"scanned":/d; /"@timestamp":/d' "$file"
}

# Helper function to strip environment-dependent fields from SARIF
strip_sarif_fields() {
  local file="$1"
  # Remove version and timestamp fields
  sed -E '/"version":/d; /"startTimeUtc":/d; /"endTimeUtc":/d' "$file"
}

################################################################################
# Test 1: Basic Image Scan with Authentication
################################################################################

@test "Test 1: Basic image scan with table output" {
  # Setup - scan from registry (not local)
  export INPUT_SCAN_REF="postgres:16-alpine"
  export INPUT_FORMAT="table"
  export SCAN_LOCAL="false"
  export IMAGE_REGISTRY_INTEGRATION="Docker Hub"

  # Run scanner
  run ./entrypoint.sh

  # Verify it completed successfully
  assert_success

  # Verify output contains expected table format markers
  assert_output --partial "Running Aqua Scanner"
  assert_output --partial "postgres:16-alpine"
}

################################################################################
# Test 2: JSON Output Format
################################################################################

@test "Test 2: JSON output format" {
  # Setup - scan from registry (not local)
  export INPUT_SCAN_REF="postgres:16-alpine"
  export INPUT_FORMAT="json"
  export INPUT_OUTPUT="${GITHUB_WORKSPACE}/results.json"
  export SCAN_LOCAL="false"
  export IMAGE_REGISTRY_INTEGRATION="Docker Hub"

  # Run scanner
  run ./entrypoint.sh

  # Verify it completed successfully
  assert_success

  # Verify JSON file was created
  assert_file_exist "${GITHUB_WORKSPACE}/results.json"

  # Verify it's valid JSON
  run jq empty "${GITHUB_WORKSPACE}/results.json"
  assert_success

  # Verify JSON structure (not exact match, as vulnerabilities change over time)
  # Check for key fields that should always be present
  run jq -e '.resources' "${GITHUB_WORKSPACE}/results.json"
  assert_success

  run jq -e '.image' "${GITHUB_WORKSPACE}/results.json"
  assert_success

  # If UPDATE_GOLDEN is set, update the golden file
  if [ -n "${UPDATE_GOLDEN}" ]; then
    cp "${GITHUB_WORKSPACE}/results.json" "test/data/json-output/expected.json"
    echo "Updated golden file: test/data/json-output/expected.json"
  fi
}

################################################################################
# Test 3: SARIF Output Format (GitHub Security)
################################################################################

@test "Test 3: SARIF output format for GitHub Security" {
  # Setup - scan from registry (not local)
  export INPUT_SCAN_REF="postgres:16-alpine"
  export INPUT_FORMAT="sarif"
  export INPUT_OUTPUT="${GITHUB_WORKSPACE}/results.sarif"
  export SCAN_LOCAL="false"
  export IMAGE_REGISTRY_INTEGRATION="Docker Hub"

  # Run scanner
  run ./entrypoint.sh

  # Verify it completed successfully
  assert_success

  # Verify SARIF file was created
  assert_file_exist "${GITHUB_WORKSPACE}/results.sarif"

  # Verify it's valid JSON (SARIF is JSON format)
  run jq empty "${GITHUB_WORKSPACE}/results.sarif"
  assert_success

  # Verify it contains SARIF schema
  run jq -r '.version' "${GITHUB_WORKSPACE}/results.sarif"
  assert_output "2.1.0"

  # Verify SARIF structure (not exact match, as vulnerabilities change over time)
  # Check for required SARIF fields
  run jq -e '.runs' "${GITHUB_WORKSPACE}/results.sarif"
  assert_success

  run jq -e '.runs[0].results' "${GITHUB_WORKSPACE}/results.sarif"
  assert_success

  # If UPDATE_GOLDEN is set, update the golden file
  if [ -n "${UPDATE_GOLDEN}" ]; then
    cp "${GITHUB_WORKSPACE}/results.sarif" "test/data/sarif-output/expected.sarif"
    echo "Updated golden file: test/data/sarif-output/expected.sarif"
  fi
}

################################################################################
# Test 4: Registry Integration & Policy Compliance
################################################################################

@test "Test 4: Registry integration and policy compliance flags" {
  # Setup - scan from registry (not local)
  export INPUT_SCAN_REF="postgres:16-alpine"
  export INPUT_FORMAT="table"
  export IMAGE_REGISTRY_INTEGRATION="Docker Hub"
  export REGISTER_COMPLIANT="true"
  export SCAN_LOCAL="false"

  # Run scanner
  run ./entrypoint.sh

  # Verify it completed (may fail due to policy, that's expected)
  # We're just checking that the flags are passed correctly
  # Exit code could be 0 (compliant) or non-zero (non-compliant)

  # Verify scanner was invoked (output should mention Aqua Scanner)
  assert_output --partial "Running Aqua Scanner"
}

################################################################################
# Test 5: Registry Image Scan (scan-local=false)
################################################################################

@test "Test 5: Registry image scan with scan-local=false" {
  # Setup - scan image from registry integration (not local)
  export INPUT_SCAN_REF="postgres:16-alpine"
  export INPUT_FORMAT="table"
  export SCAN_LOCAL="false"
  export IMAGE_REGISTRY_INTEGRATION="Docker Hub"

  # Run scanner
  run ./entrypoint.sh

  # Verify it completed successfully
  assert_success

  # Verify output
  assert_output --partial "Running Aqua Scanner"
  assert_output --partial "postgres:16-alpine"
}


#!/bin/bash
set -euo pipefail

echo "======================================"
echo "Aqua Scanner (Trivy Premium) Action - Manual Test"
echo "======================================"
echo ""

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
  echo "❌ ERROR: Docker is not running. Please start Docker and try again."
  exit 1
fi
echo "✅ Docker is running"

# Check if entrypoint.sh exists
if [ ! -f "./entrypoint.sh" ]; then
  echo "❌ ERROR: entrypoint.sh not found. Run this script from the project root."
  exit 1
fi
echo "✅ entrypoint.sh found"

# Prompt for credentials securely
echo ""
echo "Please provide your Aqua credentials:"
echo ""

read -p "AQUA_SERVER (e.g., https://company.cloud.aquasec.com): " AQUA_SERVER
read -p "AQUA_TOKEN: " AQUA_TOKEN
read -p "AQUA_REGISTRY_USERNAME: " AQUA_REGISTRY_USERNAME
read -sp "AQUA_REGISTRY_PASSWORD: " AQUA_REGISTRY_PASSWORD
echo ""

# Validate inputs
if [ -z "$AQUA_SERVER" ] || [ -z "$AQUA_TOKEN" ] || [ -z "$AQUA_REGISTRY_USERNAME" ] || [ -z "$AQUA_REGISTRY_PASSWORD" ]; then
  echo "❌ ERROR: All credentials are required"
  exit 1
fi

echo ""
echo "======================================"
echo "Step 1: Testing Docker Login to Aqua Registry"
echo "======================================"

# Test Docker login
if echo "$AQUA_REGISTRY_PASSWORD" | docker login registry.aquasec.com -u "$AQUA_REGISTRY_USERNAME" --password-stdin; then
  echo "✅ Successfully authenticated to registry.aquasec.com"
else
  echo "❌ Failed to authenticate to registry.aquasec.com"
  exit 1
fi

echo ""
echo "======================================"
echo "Step 2: Available Local Images"
echo "======================================"
docker images --format "table {{.Repository}}:{{.Tag}}\t{{.Size}}" | head -10

echo ""
read -p "Enter image to scan (default: postgres:16-alpine): " TEST_IMAGE
TEST_IMAGE=${TEST_IMAGE:-postgres:16-alpine}

# Check if image exists locally
if ! docker image inspect "$TEST_IMAGE" >/dev/null 2>&1; then
  echo "❌ ERROR: Image $TEST_IMAGE not found locally"
  exit 1
fi
echo "✅ Image $TEST_IMAGE found locally"

echo ""
echo "======================================"
echo "Step 3: Setting Up Test Environment"
echo "======================================"

# Export required environment variables
export AQUA_SERVER
export AQUA_TOKEN
export SCANNER_VERSION="saas-latest"
export INPUT_SCAN_REF="$TEST_IMAGE"
export INPUT_FORMAT="table"
export GITHUB_WORKSPACE="$(pwd)"
export SCAN_LOCAL="true"

echo "AQUA_SERVER: $AQUA_SERVER"
echo "SCANNER_VERSION: $SCANNER_VERSION"
echo "INPUT_SCAN_REF: $TEST_IMAGE"
echo "INPUT_FORMAT: table"
echo "GITHUB_WORKSPACE: $GITHUB_WORKSPACE"
echo "SCAN_LOCAL: true"

echo ""
echo "======================================"
echo "Step 4: Running Aqua Scanner"
echo "======================================"
echo ""

# Run the entrypoint script
if ./entrypoint.sh; then
  EXIT_CODE=0
  echo ""
  echo "======================================"
  echo "✅ TEST PASSED"
  echo "======================================"
  echo "Scan completed successfully!"
else
  EXIT_CODE=$?
  echo ""
  echo "======================================"
  echo "❌ TEST FAILED"
  echo "======================================"
  echo "Scanner exited with code: $EXIT_CODE"
fi

# Cleanup - docker logout
docker logout registry.aquasec.com >/dev/null 2>&1 || true

echo ""
echo "Test completed. Credentials cleared from environment."

exit $EXIT_CODE

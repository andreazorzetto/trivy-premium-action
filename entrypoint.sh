#!/bin/bash
set -euo pipefail

# Set scan target
scanRef="${INPUT_SCAN_REF:-.}"

# Build scanner image reference
SCANNER_IMAGE="registry.aquasec.com/scanner:${SCANNER_VERSION}"
echo "Using Aqua Scanner image: ${SCANNER_IMAGE}"

# Build docker run command
dockerCmd=(docker run --rm)

# Mount Docker socket for scanning local images
# Security note: This grants the scanner container access to the Docker daemon.
# This is required for local image scanning and is standard practice for container scanning tools.
dockerCmd+=(-v /var/run/docker.sock:/var/run/docker.sock)

# Mount workspace for file scanning and output
dockerCmd+=(-v "${GITHUB_WORKSPACE}:${GITHUB_WORKSPACE}")
dockerCmd+=(-w "${GITHUB_WORKSPACE}")

# Mount output directory if specified
if [ -n "${INPUT_OUTPUT:-}" ]; then
  output_dir=$(dirname "${INPUT_OUTPUT}")
  if [ "$output_dir" != "." ]; then
    mkdir -p "$output_dir"
    dockerCmd+=(-v "${PWD}/${output_dir}:${PWD}/${output_dir}")
  fi
fi

# Add scanner image
dockerCmd+=("${SCANNER_IMAGE}")

# Scanner command
dockerCmd+=(scan)

# Aqua server and authentication
dockerCmd+=(-H "${AQUA_SERVER}")
dockerCmd+=(-A "${AQUA_TOKEN}")

# Scan flags
if [ "${SCAN_LOCAL:-true}" = "true" ]; then
  dockerCmd+=(--local)
fi

if [ -n "${IMAGE_REGISTRY_INTEGRATION:-}" ]; then
  dockerCmd+=(--registry "${IMAGE_REGISTRY_INTEGRATION}")
fi

if [ "${REGISTER_COMPLIANT:-false}" = "true" ]; then
  dockerCmd+=(--register-compliant)
fi

# Always show text output for pipeline visibility
dockerCmd+=(--text)

# Output format and file
if [ -n "${INPUT_FORMAT:-}" ] && [ "${INPUT_FORMAT}" != "table" ]; then
  case "${INPUT_FORMAT}" in
    json)
      dockerCmd+=(--jsonfile "${INPUT_OUTPUT:-/dev/stdout}")
      ;;
    sarif)
      dockerCmd+=(--sarif)
      # Use default filename if not specified
      SARIF_FILE="${INPUT_OUTPUT:-aqua-results.sarif}"
      dockerCmd+=(--sariffile "${SARIF_FILE}")
      # Export for use in action.yaml upload step
      echo "SARIF_FILE=${SARIF_FILE}" >> "${GITHUB_ENV}"
      ;;
    html)
      dockerCmd+=(--html)
      if [ -n "${INPUT_OUTPUT:-}" ]; then
        dockerCmd+=(--htmlfile "${INPUT_OUTPUT}")
      fi
      ;;
  esac
fi

# Scan target (image reference or path)
dockerCmd+=("${scanRef}")

# Run scanner
echo "Running Aqua Scanner..."
# Note: Full command output is suppressed to avoid leaking AQUA_TOKEN in logs
"${dockerCmd[@]}"

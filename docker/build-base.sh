#!/bin/bash
# Build the base dev container image
#
# Usage: ./build-base.sh [tag]
#
# Example:
#   ./build-base.sh              # builds dom/devcontainer:latest
#   ./build-base.sh v1           # builds dom/devcontainer:v1

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TAG="${1:-latest}"
IMAGE_NAME="dom/devcontainer:${TAG}"

echo "Building base dev container: ${IMAGE_NAME}"
echo ""

docker build \
    -t "${IMAGE_NAME}" \
    -f "${SCRIPT_DIR}/Dockerfile.devcontainer" \
    "${SCRIPT_DIR}"

echo ""
echo "Built: ${IMAGE_NAME}"
echo ""
echo "Use in your project's .devcontainer/Dockerfile:"
echo ""
echo "  FROM dom/devcontainer:${TAG}"
echo "  # Add project-specific setup here"
echo ""

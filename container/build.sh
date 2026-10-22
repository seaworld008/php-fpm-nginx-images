#!/bin/bash
#
# Build production image with full configuration
#
set -euo pipefail

cd "$(dirname "$0")"

IMAGE_NAME="jwxt-nginx-php72"
IMAGE_TAG="v100.20261022"
BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

echo "=========================================="
echo "Building Production Image"
echo "=========================================="
echo "Image: ${IMAGE_NAME}:${IMAGE_TAG}"
echo "Date: ${BUILD_DATE}"
echo ""

docker build \
    --progress=plain \
    --no-cache \
    --build-arg BUILD_DATE="${BUILD_DATE}" \
    -t "${IMAGE_NAME}:${IMAGE_TAG}" \
    -t "${IMAGE_NAME}:latest" \
    -f Dockerfile.production \
    .

echo ""
echo "=========================================="
echo "Build Complete!"
echo "=========================================="
echo ""
echo "Image: ${IMAGE_NAME}:${IMAGE_TAG}"
echo "Also tagged as: ${IMAGE_NAME}:latest"
echo ""
echo "Run validation:"
echo "  ./tests/quick-validate.sh ${IMAGE_NAME}:${IMAGE_TAG}"
echo ""
echo "Test Jenkins compatibility:"
echo "  ./tests/jenkins-compat-test.sh ${IMAGE_NAME}:${IMAGE_TAG}"
echo ""

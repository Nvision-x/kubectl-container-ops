#!/bin/bash
set -e

echo "🐳 Testing Docker build and functionality..."

# Configuration
KUBECTL_VERSION="v1.34.1"
TEST_IMAGE="kubectl-container-ops:test"

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Docker Desktop."
    exit 1
fi

echo "✅ Docker is running"

# Build the image
echo "🏗️  Building Docker image..."
if docker build --build-arg KUBECTL_VERSION="$KUBECTL_VERSION" -t "$TEST_IMAGE" .; then
    echo "✅ Docker build successful!"
else
    echo "❌ Docker build failed"
    exit 1
fi

# Test basic functionality
echo "🧪 Testing image functionality..."

echo "  📋 Testing kubectl version..."
if docker run --rm "$TEST_IMAGE" version --client; then
    echo "  ✅ kubectl works!"
else
    echo "  ❌ kubectl test failed"
    exit 1
fi

echo "  📋 Testing additional tools..."
if docker run --rm --entrypoint=/bin/sh "$TEST_IMAGE" -c "
    echo '✅ kubectl:' && kubectl version --client | head -1 &&
    echo '✅ jq:' && echo '{\"test\":\"ok\"}' | jq -r .test &&
    echo '✅ curl:' && curl --version | head -1
"; then
    echo "  ✅ All tools work correctly!"
else
    echo "  ❌ Tool tests failed"
    exit 1
fi

echo "  📋 Testing read-only filesystem compatibility..."
if docker run --rm --read-only "$TEST_IMAGE" version --client; then
    echo "  ✅ Read-only filesystem test passed!"
else
    echo "  ❌ Read-only filesystem test failed"
    exit 1
fi

echo "  📋 Testing with dropped capabilities..."
if docker run --rm --cap-drop=ALL "$TEST_IMAGE" version --client; then
    echo "  ✅ Dropped capabilities test passed!"
else
    echo "  ❌ Dropped capabilities test failed"
    exit 1
fi

# Check image size
IMAGE_SIZE=$(docker images "$TEST_IMAGE" --format "table {{.Size}}" | tail -n1)
echo "📊 Image size: $IMAGE_SIZE"

# Cleanup
echo "🧹 Cleaning up test image..."
docker rmi "$TEST_IMAGE"

echo "✅ All Docker tests passed!"
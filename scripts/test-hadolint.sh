#!/bin/bash
set -e

echo "🔍 Testing Dockerfile with Hadolint..."

# Check if hadolint is installed
if ! command -v hadolint &> /dev/null; then
    echo "📦 Installing Hadolint..."
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        if command -v brew &> /dev/null; then
            brew install hadolint
        else
            echo "❌ Please install Homebrew first or install hadolint manually"
            exit 1
        fi
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux
        wget -O hadolint https://github.com/hadolint/hadolint/releases/latest/download/hadolint-Linux-x86_64
        sudo mv hadolint /usr/local/bin/hadolint
        sudo chmod +x /usr/local/bin/hadolint
    else
        echo "❌ Unsupported OS. Please install hadolint manually"
        exit 1
    fi
fi

echo "✅ Hadolint version: $(hadolint --version)"

# Run hadolint with our configuration
echo "🔍 Linting Dockerfile..."
if hadolint Dockerfile; then
    echo "✅ Dockerfile passed hadolint checks!"
else
    echo "❌ Dockerfile has linting issues"
    exit 1
fi
#!/bin/bash
set -e

echo "🔍 Testing shell scripts with shellcheck..."

# Check if shellcheck is installed
if ! command -v shellcheck &> /dev/null; then
    echo "📦 Installing shellcheck..."
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        if command -v brew &> /dev/null; then
            brew install shellcheck
        else
            echo "❌ Please install Homebrew first or install shellcheck manually"
            exit 1
        fi
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux
        sudo apt-get update && sudo apt-get install -y shellcheck
    else
        echo "❌ Unsupported OS. Please install shellcheck manually"
        exit 1
    fi
fi

echo "✅ Shellcheck version: $(shellcheck --version | grep version)"

# Find and check all shell scripts
SHELL_SCRIPTS=$(find . -name "*.sh" -type f)

if [ -z "$SHELL_SCRIPTS" ]; then
    echo "⚠️  No shell scripts found to check"
    exit 0
fi

echo "🔍 Found shell scripts:"
echo "$SHELL_SCRIPTS"
echo ""

echo "🔍 Running shellcheck on all shell scripts..."
if find . -name "*.sh" -type f -exec shellcheck {} +; then
    echo "✅ All shell scripts passed shellcheck!"
else
    echo "❌ Shell scripts have issues"
    exit 1
fi
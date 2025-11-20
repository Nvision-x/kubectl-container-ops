#!/bin/bash

# Local CI/CD Test Runner
# Simulates the GitHub Actions workflow locally

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SKIP_DOCKER=${SKIP_DOCKER:-false}
SKIP_SECURITY=${SKIP_SECURITY:-true}  # Skip security by default (requires tools)

echo -e "${BLUE}🚀 kubectl Container Ops - Local Test Runner${NC}"
echo "================================================"
echo "This script runs the same tests as the GitHub Actions workflow"
echo ""

# Function to print step headers
print_step() {
    echo -e "\n${BLUE}🔧 $1${NC}"
    echo "----------------------------------------"
}

# Function to print success
print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

# Function to print error
print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Function to print warning
print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Cleanup function
cleanup() {
    print_step "Cleaning up"
    # Remove any temporary files
    rm -f trivy-fs-results.sarif trivy-secret-results.sarif
    echo "Cleanup completed"
}

# Set trap for cleanup on exit
trap cleanup EXIT

# Step 1: File Permissions Check
print_step "Checking file permissions"

if [ -x entrypoint.sh ]; then
    print_success "entrypoint.sh is executable"
else
    print_error "entrypoint.sh is not executable"
    echo "Run: chmod +x entrypoint.sh"
    exit 1
fi

# Check for sensitive files
SENSITIVE_FILES=$(find . -name "*.key" -o -name "*.pem" -o -name "*.p12" | head -5)
if [ -n "$SENSITIVE_FILES" ]; then
    print_error "Found sensitive files in repository:"
    echo "$SENSITIVE_FILES"
    exit 1
else
    print_success "No sensitive files found"
fi

# Step 2: Makefile Validation
if [ -f "Makefile" ]; then
    print_step "Validating Makefile"
    
    if make --version >/dev/null 2>&1; then
        print_success "GNU Make is available"
    else
        print_warning "GNU Make not found, skipping Makefile validation"
    fi
    
    if make -n help >/dev/null 2>&1; then
        print_success "Makefile syntax is valid"
    else
        print_warning "Makefile validation failed or help target not found"
    fi
else
    print_warning "No Makefile found"
fi

# Step 3: Hadolint (Dockerfile linting)
print_step "Running Dockerfile linting"
if [ -f "scripts/test-hadolint.sh" ]; then
    chmod +x scripts/test-hadolint.sh
    if ./scripts/test-hadolint.sh; then
        print_success "Hadolint tests passed"
    else
        print_error "Hadolint tests failed"
        exit 1
    fi
else
    print_warning "Hadolint test script not found"
fi

# Step 4: Shellcheck (Shell script linting)
print_step "Running shell script linting"
if [ -f "scripts/test-shellcheck.sh" ]; then
    chmod +x scripts/test-shellcheck.sh
    if ./scripts/test-shellcheck.sh; then
        print_success "Shellcheck tests passed"
    else
        print_error "Shellcheck tests failed"
        exit 1
    fi
else
    print_warning "Shellcheck test script not found"
fi

# Step 5: Security Scanning (Optional)
if [ "$SKIP_SECURITY" = "false" ]; then
    print_step "Running security scans"
    
    # Check for insecure HTTP URLs
    if grep -r "curl.*http://" . --exclude-dir=.git >/dev/null 2>&1; then
        print_error "Found insecure HTTP URLs in scripts"
        exit 1
    else
        print_success "No insecure HTTP URLs found"
    fi
    
    # Check for hardcoded credentials
    if grep -rE "(password|token|key|secret).*=" . --exclude-dir=.git --include="*.sh" --include="*.yml" >/dev/null 2>&1; then
        print_error "Potential hardcoded credentials found"
        exit 1
    else
        print_success "No hardcoded credentials found"
    fi
    
    # Trivy scanning (if available)
    if command -v trivy >/dev/null 2>&1; then
        print_step "Running Trivy filesystem scan"
        if trivy fs --format sarif --output trivy-fs-results.sarif .; then
            print_success "Trivy filesystem scan completed"
        else
            print_warning "Trivy filesystem scan had issues"
        fi
    else
        print_warning "Trivy not installed, skipping vulnerability scanning"
        print_warning "Install with: brew install aquasecurity/trivy/trivy (macOS)"
    fi
else
    print_warning "Security scanning skipped (set SKIP_SECURITY=false to enable)"
fi

# Step 6: Docker Build and Test
if [ "$SKIP_DOCKER" = "false" ]; then
    print_step "Running Docker build and tests"
    if [ -f "scripts/test-docker.sh" ]; then
        chmod +x scripts/test-docker.sh
        if ./scripts/test-docker.sh; then
            print_success "Docker tests passed"
        else
            print_error "Docker tests failed"
            exit 1
        fi
    else
        print_warning "Docker test script not found"
    fi
else
    print_warning "Docker testing skipped (set SKIP_DOCKER=false to enable)"
fi

# Final Summary
echo ""
echo "================================================"
print_success "All local tests completed successfully! 🎉"
echo ""
echo "Your code should pass the GitHub Actions workflow."
echo ""
echo "To run specific test suites:"
echo "  • Dockerfile linting: ./scripts/test-hadolint.sh"
echo "  • Shell script linting: ./scripts/test-shellcheck.sh" 
echo "  • Docker build & test: ./scripts/test-docker.sh"
echo ""
echo "To run with all features:"
echo "  • SKIP_DOCKER=false SKIP_SECURITY=false ./scripts/test-local.sh"
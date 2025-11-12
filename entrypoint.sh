#!/bin/bash
# kubectl entrypoint script
set -e

# Simple kubectl passthrough
# If called directly as kubectl, just execute kubectl with all arguments
if [ "$(basename "$0")" = "kubectl" ] || [ "$1" = "kubectl" ]; then
    shift 2>/dev/null || true  # Remove 'kubectl' if it's the first arg
    exec /opt/kubectl/bin/kubectl "$@"
fi

# Enhanced functionality for direct script execution
# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1" >&2
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" >&2
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" >&2
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# Initialize kubectl configuration if environment variables are provided
init_kubectl_config() {
    # Only initialize if we have config content or server info
    if [ -n "${KUBECONFIG_CONTENT:-}" ] || [ -n "${KUBE_SERVER:-}" ]; then
        print_info "Configuring kubectl..."
        
        # Ensure .kube directory exists
        mkdir -p /.kube
        
        # Method 1: Base64 encoded kubeconfig
        if [ -n "${KUBECONFIG_CONTENT:-}" ]; then
            print_info "Setting up config from KUBECONFIG_CONTENT..."
            echo "${KUBECONFIG_CONTENT}" | base64 -d > /.kube/config 2>/dev/null || {
                print_error "Failed to decode KUBECONFIG_CONTENT"
                return 1
            }
            chmod 600 /.kube/config
        fi
        
        # Method 2: Server and token
        if [ -n "${KUBE_SERVER:-}" ] && [ -n "${KUBE_TOKEN:-}" ]; then
            print_info "Setting up config from server and token..."
            kubectl config set-cluster default --server="${KUBE_SERVER}" --insecure-skip-tls-verify=true
            kubectl config set-credentials default --token="${KUBE_TOKEN}"
            kubectl config set-context default --cluster=default --user=default
            kubectl config use-context default
            
            # Set namespace if provided
            if [ -n "${KUBE_NAMESPACE:-}" ]; then
                kubectl config set-context --current --namespace="${KUBE_NAMESPACE}"
            fi
        fi
        
        # Test connection
        if kubectl cluster-info >/dev/null 2>&1; then
            print_success "kubectl configured successfully"
        else
            print_warning "kubectl configured but cluster connection test failed"
        fi
    fi
}

# Show help
show_help() {
    cat << 'EOF'
kubectl container

USAGE:
  kubectl [kubectl-args...]     # Direct kubectl execution
  
ENVIRONMENT VARIABLES:
  KUBECONFIG_CONTENT   Base64-encoded kubeconfig
  KUBE_SERVER         Kubernetes server URL
  KUBE_TOKEN          Authentication token
  KUBE_NAMESPACE      Default namespace

EXAMPLES:
  # Direct kubectl usage
  docker run --rm kubectl-ops get pods
  
  # With mounted config
  docker run --rm -v ~/.kube/config:/.kube/config:ro kubectl-ops get nodes
  
  # With environment config
  docker run --rm -e KUBE_SERVER=https://... -e KUBE_TOKEN=... kubectl-ops version

EOF
}

# Main execution
if [ $# -eq 0 ]; then
    # No arguments - show help and version
    show_help
    echo "kubectl version:"
    /opt/kubectl/bin/kubectl version --client 2>/dev/null || true
else
    case "$1" in
        "help"|"--help"|"-h")
            show_help
            ;;
        "bash"|"sh"|"/bin/bash"|"/bin/sh")
            # Interactive shell mode
            print_info "Starting interactive shell..."
            init_kubectl_config
            exec "$@"
            ;;
        *)
            # Initialize config if needed, then execute kubectl
            init_kubectl_config
            exec /opt/kubectl/bin/kubectl "$@"
            ;;
    esac
fi
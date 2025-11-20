# kubectl Container Ops

## Features

- **Ultra-lightweight**: Based on Alpine Linux (~92MB, 55% smaller than alternatives)
- **Secure**: Runs as non-root user (UID 1001)
- **Flexible**: Multiple configuration methods
- **Complete**: Includes kubectl + essential tools (curl, jq, yq, git)
- **Optimized**: AMD64 architecture for maximum performance
- **Health checks**: Built-in container health monitoring
- **Enterprise-ready**: Following industry best practices

### Automation Triggers & Versioning

- **Push to main**: Full pipeline with CalVer auto-release (YYYY.MM.DD-BUILD)
- **Pull requests**: Build and test validation
- **Tag releases**: Complete pipeline + GitHub release
- **Weekly schedule**: Security scans and dependency updates

### CalVer Implementation

The project uses **Calendar Versioning (CalVer)** following the pattern:

```
Format: YYYY.MM.DD-PATCH
Example: 2025.10.31-42
```

- **Automatic CalVer**: Generated on every main branch build
- **Auto-releases**: Triggered on successful main branch builds
- **Traceability**: Each build number links to specific commit and date

## 📦 What's Included

- `kubectl` (configurable version, default: v1.34.1)
- `curl` - HTTP client
- `jq` - JSON processor
- `yq` - YAML processor
- `git` - Version control
- `bash` - Interactive shell

## 🛠 Quick Start

### Build the Image

```bash
# Basic build
make build

# Build with specific kubectl version
make build KUBECTL_VERSION=v1.29.0

# Build without cache
make build-no-cache
```

### Run Examples

```bash
# Interactive shell with mounted kubeconfig
make run

# Run specific kubectl command
make run-cmd CMD="kubectl get pods"

# Use the published container directly
docker run --rm -v ~/.kube/config:/.kube/config:ro ghcr.io/nvision-x/kubectl-container-ops:latest get pods

# Use specific version
docker run --rm -v ~/.kube/config:/.kube/config:ro ghcr.io/nvision-x/kubectl-container-ops:2025.11.20-1 version --client

# Just test the container
make test-run
```

## 🔧 Configuration Methods

### Method 1: Mount kubeconfig file

```bash
docker run --rm -v ~/.kube/config:/.kube/config:ro kubectl-ops get nodes
```

### Method 2: Environment variables

```bash
docker run --rm \
  -e KUBE_SERVER=https://your-cluster-api.com \
  -e KUBE_TOKEN=your-service-account-token \
  -e KUBE_NAMESPACE=default \
  kubectl-ops get pods
```

### Method 3: Base64 encoded config

```bash
# Encode your kubeconfig
KUBECONFIG_B64=$(cat ~/.kube/config | base64)

docker run --rm \
  -e KUBECONFIG_CONTENT="$KUBECONFIG_B64" \
  kubectl-ops cluster-info
```

## 📋 Environment Variables

| Variable               | Description                    | Example                            |
| ---------------------- | ------------------------------ | ---------------------------------- |
| `KUBECONFIG_CONTENT` | Base64-encoded kubeconfig file | `$(cat ~/.kube/config \| base64)` |
| `KUBE_SERVER`        | Kubernetes API server URL      | `https://api.cluster.local`      |
| `KUBE_TOKEN`         | Service account or user token  | `eyJhbGciOiJSUzI1Ni...`          |
| `KUBE_NAMESPACE`     | Default namespace              | `production`                     |
| `KUBECTL_CONFIG`     | Path to kubeconfig file        | `/home/kubectl/.kube/config`     |

## 🔨 Makefile Commands

### Build & Test

```bash
make build          # Build the image
make build-no-cache # Build without cache  
make test-run       # Quick test
make validate       # Lint Dockerfile and scripts
make all           # Validate + build + test
```

### Development

```bash
make run           # Interactive shell
make shell         # Shell with workspace mounted
make inspect       # Inspect image details
make size          # Show image size
```

### Registry Operations

```bash
make push REGISTRY=your-registry.com    # Push to registry
make pull REGISTRY=your-registry.com    # Pull from registry
```

### Examples

```bash
make example-version      # Show kubectl version
make example-cluster-info # Show cluster info  
make example-get-pods     # List all pods
```

### Cleanup

```bash
make clean      # Remove built image
make clean-all  # Remove all kubectl-ops images
make prune      # Docker system cleanup
```

## 🛡 Security Features

- **Non-root execution**: Runs as user `kubectl` (UID 1001)
- **Minimal attack surface**: Alpine-based with only essential packages
- **Read-only mounts**: Kubeconfig mounted read-only by default
- **No privileged access**: Container requires no special permissions

## 🏗 Build Arguments

| Argument            | Default     | Description                |
| ------------------- | ----------- | -------------------------- |
| `KUBECTL_VERSION` | `v1.28.3` | kubectl version to install |

```bash
# Build with specific kubectl version
docker build --build-arg KUBECTL_VERSION=v1.29.0 -t kubectl-ops .
```

## 🐛 Troubleshooting

### Common Issues

**Container can't connect to cluster:**

```bash
# Check if kubeconfig is properly mounted
docker run --rm -v ~/.kube/config:/home/kubectl/.kube/config:ro kubectl-ops cat ~/.kube/config

# Verify kubectl can see the config
docker run --rm -v ~/.kube/config:/home/kubectl/.kube/config:ro kubectl-ops kubectl config view
```

**Permission denied errors:**

```bash
# Ensure kubeconfig has correct permissions
chmod 600 ~/.kube/config

# Check file ownership
ls -la ~/.kube/config
```

**Environment variable issues:**

```bash
# Test with debug mode
docker run --rm -e KUBECONFIG_CONTENT="$KUBECONFIG_B64" kubectl-ops bash -c "echo \$KUBECONFIG_CONTENT | base64 -d"
```

### Debug Mode

```bash
# Run with verbose output
docker run --rm -v ~/.kube/config:/home/kubectl/.kube/config:ro kubectl-ops kubectl --v=6 get nodes
```

## 📊 Image Details

- **Base Image**: Alpine Linux 3.19
- **Size**: ~92MB (55% smaller than enterprise alternatives)
- **Platforms**: linux/amd64, linux/arm64
- **User**: kubectl (1001:1001)
- **Workdir**: /
- **Entrypoint**: kubectl (direct execution)

# kubectl Container Operations Makefile
# Variables
IMAGE_NAME ?= kubectl-ops
IMAGE_TAG ?= latest
REGISTRY ?= 
KUBECTL_VERSION ?= v1.34.1
PLATFORM ?= linux/amd64

# Full image name
FULL_IMAGE_NAME = $(if $(REGISTRY),$(REGISTRY)/)$(IMAGE_NAME):$(IMAGE_TAG)

# Default target
.DEFAULT_GOAL := help

# Help target
.PHONY: help
help: ## Show this help message
	@echo "kubectl Container Operations"
	@echo "=========================="
	@echo ""
	@echo "Available targets:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo ""
	@echo "Variables:"
	@echo "  IMAGE_NAME=$(IMAGE_NAME)"
	@echo "  IMAGE_TAG=$(IMAGE_TAG)"
	@echo "  REGISTRY=$(REGISTRY)"
	@echo "  KUBECTL_VERSION=$(KUBECTL_VERSION)"
	@echo "  PLATFORM=$(PLATFORM)"

# CalVer helpers
.PHONY: calver
calver: ## Generate CalVer tag (YYYY.MM.DD-BUILD)
	@CALVER_TAG="$$(date +%Y.%m.%d)-$${BUILD_NUMBER:-1}" && \
	echo "Generated CalVer: v$$CALVER_TAG" && \
	echo "$$CALVER_TAG"

.PHONY: build-calver
build-calver: ## Build with CalVer tag
	@CALVER_TAG="$$(date +%Y.%m.%d)-$${BUILD_NUMBER:-1}" && \
	$(MAKE) build IMAGE_TAG="$$CALVER_TAG" && \
	$(MAKE) build IMAGE_TAG="latest"

# Build targets
.PHONY: build
build: ## Build the Docker image with build metadata
	@echo "Building $(FULL_IMAGE_NAME)..."
	docker build \
		--build-arg KUBECTL_VERSION=$(KUBECTL_VERSION) \
		--build-arg BUILD_DATE=$(shell date -u +'%Y-%m-%dT%H:%M:%SZ') \
		--build-arg VCS_REF=$(shell git rev-parse --short HEAD 2>/dev/null || echo "unknown") \
		--tag $(FULL_IMAGE_NAME) \
		--platform $(PLATFORM) \
		--progress=plain \
		.
	@echo "Build complete: $(FULL_IMAGE_NAME)"

.PHONY: build-no-cache
build-no-cache: ## Build the Docker image without cache
	@echo "Building $(FULL_IMAGE_NAME) without cache..."
	docker build \
		--no-cache \
		--build-arg KUBECTL_VERSION=$(KUBECTL_VERSION) \
		--tag $(FULL_IMAGE_NAME) \
		--platform $(PLATFORM) \
		.
	@echo "Build complete: $(FULL_IMAGE_NAME)"

.PHONY: buildx
buildx: ## Build multi-platform image using buildx
	@echo "Building multi-platform $(FULL_IMAGE_NAME)..."
	docker buildx build \
		--build-arg KUBECTL_VERSION=$(KUBECTL_VERSION) \
		--tag $(FULL_IMAGE_NAME) \
		--platform $(PLATFORM) \
		--push \
		.

# Run targets
.PHONY: run
run: ## Run the container interactively
	docker run --rm -it \
		-v ~/.kube/config:/.kube/config:ro \
		$(FULL_IMAGE_NAME) bash

.PHONY: run-cmd
run-cmd: ## Run a specific kubectl command (use CMD="your command")
	docker run --rm \
		-v ~/.kube/config:/.kube/config:ro \
		$(FULL_IMAGE_NAME) $(CMD)

.PHONY: test-run
test-run: ## Test run the container
	docker run --rm $(FULL_IMAGE_NAME)

# Registry operations
.PHONY: push
push: ## Push the image to registry
	@if [ -z "$(REGISTRY)" ]; then \
		echo "Error: REGISTRY variable is required for push"; \
		echo "Usage: make push REGISTRY=your-registry.com"; \
		exit 1; \
	fi
	@echo "Pushing $(FULL_IMAGE_NAME)..."
	docker push $(FULL_IMAGE_NAME)

.PHONY: pull
pull: ## Pull the image from registry
	@if [ -z "$(REGISTRY)" ]; then \
		echo "Error: REGISTRY variable is required for pull"; \
		echo "Usage: make pull REGISTRY=your-registry.com"; \
		exit 1; \
	fi
	@echo "Pulling $(FULL_IMAGE_NAME)..."
	docker pull $(FULL_IMAGE_NAME)

# Development targets
.PHONY: shell
shell: ## Start a shell in the container
	docker run --rm -it \
		-v ~/.kube/config:/.kube/config:ro \
		-v $(PWD):/workspace \
		-w /workspace \
		$(FULL_IMAGE_NAME) bash

.PHONY: inspect
inspect: ## Inspect the built image
	docker inspect $(FULL_IMAGE_NAME)

.PHONY: history
history: ## Show image history/layers
	docker history $(FULL_IMAGE_NAME)

.PHONY: size
size: ## Show image size
	docker images $(IMAGE_NAME) --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"

# Cleanup targets
.PHONY: clean
clean: ## Remove the built image
	docker rmi $(FULL_IMAGE_NAME) || true

.PHONY: clean-all
clean-all: ## Remove all kubectl-ops images
	docker rmi $$(docker images $(IMAGE_NAME) -q) || true

.PHONY: prune
prune: ## Prune Docker system (remove unused images, containers, etc.)
	docker system prune -f

# Security scanning
.PHONY: scan
scan: ## Scan image for vulnerabilities (requires docker scan or trivy)
	@if command -v trivy >/dev/null 2>&1; then \
		echo "Scanning with Trivy..."; \
		trivy image --severity HIGH,CRITICAL $(FULL_IMAGE_NAME); \
	elif docker scan --version >/dev/null 2>&1; then \
		echo "Scanning with Docker scan..."; \
		docker scan $(FULL_IMAGE_NAME); \
	else \
		echo "No security scanner found. Install trivy or enable docker scan."; \
	fi

.PHONY: scan-full
scan-full: ## Full security scan including low-medium vulnerabilities
	@if command -v trivy >/dev/null 2>&1; then \
		echo "Full security scan with Trivy..."; \
		trivy image --severity LOW,MEDIUM,HIGH,CRITICAL $(FULL_IMAGE_NAME); \
	else \
		echo "Trivy not found. Install with: brew install trivy"; \
	fi

.PHONY: security-check
security-check: ## Run comprehensive security checks
	@echo "Running security validation..."
	@echo "1. Checking for non-root user..."
	@docker run --rm --entrypoint=/bin/sh $(FULL_IMAGE_NAME) -c "id"
	@echo "2. Checking file permissions..."
	@docker run --rm --entrypoint=/bin/sh $(FULL_IMAGE_NAME) -c "find /opt -type f -perm -002 | wc -l"
	@echo "3. Checking for setuid binaries..."
	@docker run --rm --entrypoint=/bin/sh $(FULL_IMAGE_NAME) -c "find / -type f -perm -4000 2>/dev/null | wc -l || true"
	@echo "4. Verifying kubectl works..."
	@docker run --rm $(FULL_IMAGE_NAME) version --client
	@echo "5. Checking image size..."
	@docker images $(IMAGE_NAME):$(IMAGE_TAG) --format "{{.Size}}"

# Examples
.PHONY: example-version
example-version: ## Example: Show kubectl version
	make run-cmd CMD="version --client"

.PHONY: example-cluster-info
example-cluster-info: ## Example: Show cluster info
	make run-cmd CMD="cluster-info"

.PHONY: example-get-pods
example-get-pods: ## Example: Get all pods
	make run-cmd CMD="get pods --all-namespaces"

# CI/CD helpers
.PHONY: validate
validate: ## Validate Dockerfile and scripts
	@echo "Validating Dockerfile..."
	@if command -v hadolint >/dev/null 2>&1; then \
		hadolint Dockerfile; \
	else \
		echo "hadolint not found, skipping Dockerfile linting"; \
	fi
	@echo "Validating shell scripts..."
	@if command -v shellcheck >/dev/null 2>&1; then \
		shellcheck entrypoint.sh; \
	else \
		echo "shellcheck not found, skipping shell script linting"; \
	fi

.PHONY: all
all: validate build test-run ## Run validation, build, and test
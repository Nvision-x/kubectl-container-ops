# syntax=docker/dockerfile:1.7
# Multi-stage build for kubectl container
FROM ghcr.io/nvision-x/alpine-base-dockerfile@sha256:e1c87245f926bdc2b2c694f0771f561ed07af4ded7e1037a7af8d8a897d9c9d5 AS kubectl-installer

# Build arguments with defaults and descriptions
ARG KUBECTL_VERSION=v1.34.1
ARG TARGETPLATFORM
ARG BUILDPLATFORM

# Metadata for the installer stage
LABEL stage=installer

# Set shell options for proper error handling
SHELL ["/bin/ash", "-eo", "pipefail", "-c"]

# Install dependencies for downloading kubectl (minimal set)
# Switch to root temporarily to install packages
USER root
RUN apk add --no-cache --virtual .download-deps \
    curl \
    ca-certificates

# Download and verify kubectl binary
RUN set -eux; \
    case ${TARGETPLATFORM} in \
        "linux/amd64") ARCH=amd64 ;; \
        "linux/arm64") ARCH=arm64 ;; \
        *) ARCH=amd64 ;; \
    esac; \
    echo "Downloading kubectl ${KUBECTL_VERSION} for ${ARCH}"; \
    curl -fsSLO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${ARCH}/kubectl"; \
    curl -fsSLO "https://dl.k8s.io/${KUBECTL_VERSION}/bin/linux/${ARCH}/kubectl.sha256"; \
    echo "$(cat kubectl.sha256)  kubectl" | sha256sum -c -; \
    chmod +x kubectl; \
    mkdir -p /opt/kubectl/bin; \
    mv kubectl /opt/kubectl/bin/; \
    # Clean up download dependencies \
    apk del .download-deps; \
    # Verify the binary works \
    /opt/kubectl/bin/kubectl version --client

# Final stage - minimal runtime image
FROM ghcr.io/nvision-x/alpine-base-dockerfile@sha256:e1c87245f926bdc2b2c694f0771f561ed07af4ded7e1037a7af8d8a897d9c9d5

# Build arguments (must be redeclared after FROM)
ARG KUBECTL_VERSION=v1.34.1
ARG BUILD_DATE
ARG VCS_REF

# Enhanced OCI-compliant metadata
LABEL org.opencontainers.image.title="kubectl" \
      org.opencontainers.image.description="Lightweight kubectl container with essential DevOps tools" \
      org.opencontainers.image.version="${KUBECTL_VERSION}" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.vendor="kubectl-container-ops" \
      org.opencontainers.image.source="https://github.com/your-org/kubectl-container-ops" \
      org.opencontainers.image.documentation="https://github.com/your-org/kubectl-container-ops/blob/main/README.md" \
      org.opencontainers.image.licenses="MIT" \
      maintainer="kubectl-container-ops"

# Install runtime dependencies and yq in single layer for better caching
# Switch to root temporarily to install packages
USER root
RUN set -eux; \
    # Install system packages
    apk add --no-cache \
        bash \
        curl \
        git \
        jq \
        ca-certificates; \
    # Install yq in same layer to optimize build time
    YQ_VERSION="v4.40.5"; \
    YQ_ARCH=$(uname -m); \
    case ${YQ_ARCH} in \
        x86_64) YQ_ARCH=amd64 ;; \
        aarch64) YQ_ARCH=arm64 ;; \
    esac; \
    curl -fsSL "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_${YQ_ARCH}" \
         -o /usr/local/bin/yq; \
    chmod +x /usr/local/bin/yq; \
    yq --version; \
    # Security: Remove package manager cache and temporary files
    rm -rf /var/cache/apk/* /tmp/*

# Create application directory structure
RUN mkdir -p /opt/kubectl/bin \
             /opt/kubectl/licenses \
             /opt/common/bin \
             /opt/scripts

# Copy kubectl from installer stage
COPY --from=kubectl-installer /opt/kubectl/bin/kubectl /opt/kubectl/bin/kubectl

# Create symbolic link for easy access
RUN ln -sf /opt/kubectl/bin/kubectl /usr/local/bin/kubectl

# Use existing appuser from base image instead of creating new user
# Create directories with proper permissions for appuser (uid=1000)
RUN mkdir -p /.kube /home/appuser/.kube /home/appuser/.cache && \
    # Set proper ownership and permissions for appuser \
    chown -R 1000:1000 /home/appuser /.kube && \
    chmod -R 750 /home/appuser && \
    chmod 700 /.kube

# Copy entrypoint script with proper permissions
RUN mkdir -p /opt/scripts/kubectl
COPY --chmod=755 entrypoint.sh /opt/scripts/kubectl/entrypoint.sh

# Create license file
RUN echo "kubectl is licensed under the Apache License 2.0" > /opt/kubectl/licenses/LICENSE

# Set environment variables
ENV PATH="/opt/kubectl/bin:/opt/common/bin:$PATH" \
    HOME="/" \
    OS_ARCH="$(uname -m)" \
    OS_FLAVOUR="alpine-3.19" \
    OS_NAME="linux" \
    APP_VERSION="${KUBECTL_VERSION}" \
    APP_NAME="kubectl"

# Security: Remove unnecessary setuid/setgid binaries
RUN find / -type f -perm +6000 -not -path '/proc/*' -exec ls -ld {} + 2>/dev/null || true

# Security: Remove shell history and temporary files
RUN rm -rf /tmp/* /var/tmp/* /root/.bash_history 2>/dev/null || true

# Switch to non-root user (Security best practice)
# Switch back to non-root user (appuser from base image)
USER 1000:1000
WORKDIR /

# Set environment variables with security considerations
ENV KUBECTL_CONFIG=/.kube/config \
    KUBECONFIG=/.kube/config \
    PATH="/opt/kubectl/bin:/opt/common/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
    # Security: Disable bash history \
    HISTFILE=/dev/null \
    # Performance: Disable debug output \
    KUBECTL_DISABLE_OPENAPI_VALIDATION=false

# Health check with proper timeout and intervals
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD kubectl version --client --output=json > /dev/null || exit 1

# Use SHELL form for better signal handling
SHELL ["/bin/sh", "-c"]

# Direct kubectl entrypoint (following enterprise patterns)
ENTRYPOINT ["kubectl"]
CMD ["--help"]
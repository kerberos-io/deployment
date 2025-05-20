FROM ubuntu:latest
LABEL maintainer="Cedric Verstraeten"

# Install curl
RUN apt-get update && apt-get install -y curl

# Install kind (detect architecture)
RUN ARCH=$(uname -m) && \
    if [ "$ARCH" = "x86_64" ]; then \
        curl -Lo /usr/local/bin/kind https://kind.sigs.k8s.io/dl/v0.28.0/kind-linux-amd64; \
    elif [ "$ARCH" = "aarch64" ]; then \
        curl -Lo /usr/local/bin/kind https://kind.sigs.k8s.io/dl/v0.28.0/kind-linux-arm64; \
    else \
        echo "Unsupported architecture: $ARCH" && exit 1; \
    fi && \
    chmod +x /usr/local/bin/kind

# Create a cluster using kind
RUN kind create cluster
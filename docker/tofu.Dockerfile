FROM ghcr.io/opentofu/opentofu:latest

ARG TFLINT_VERSION=v0.51.1

RUN apk add --no-cache bash curl unzip ca-certificates && \
    curl -sSL "https://github.com/terraform-linters/tflint/releases/download/${TFLINT_VERSION}/tflint_linux_amd64.zip" -o /tmp/tflint.zip && \
    unzip /tmp/tflint.zip -d /usr/local/bin && \
    rm -f /tmp/tflint.zip && \
    adduser -D -h /workspace tofu && \
    mkdir -p /workspace && chown tofu:tofu /workspace

USER tofu
WORKDIR /workspace

ENV TF_PLUGIN_CACHE_DIR=/tf-cache \
    TFLINT_CONFIG=/workspace/.tflint.hcl

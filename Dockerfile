FROM alpine:3.20

RUN apk add --no-cache bash git curl unzip hyperfine

# OpenTofu >= 1.10 (good concurrency handling for provider cache dirs)
ENV TOFU_VERSION=1.10.3
RUN curl -fsSL https://github.com/opentofu/opentofu/releases/download/v${TOFU_VERSION}/tofu_${TOFU_VERSION}_linux_amd64.zip -o /tmp/tofu.zip \
 && unzip /tmp/tofu.zip -d /usr/local/bin && chmod +x /usr/local/bin/tofu && rm /tmp/tofu.zip

# Terragrunt (recent)
ENV TERRAGRUNT_VERSION=0.86.0
RUN curl -fsSL https://github.com/gruntwork-io/terragrunt/releases/download/v${TERRAGRUNT_VERSION}/terragrunt_linux_amd64 -o /usr/local/bin/terragrunt \
 && chmod +x /usr/local/bin/terragrunt

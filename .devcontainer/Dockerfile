# Use Debian Bookworm as the base image
FROM debian:bookworm-slim

# Install ca-certificates and wget first to handle corporate certificate
RUN apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates wget && \
    wget -q --header="Host: pki-icp.canada.ca" "http://167.43.15.18/aia/GoC-GdC-Root-A.crt" -O /usr/local/share/ca-certificates/GoC-GdC-Root-A.crt && \
    update-ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Set SSL certificate environment variables for all subsequent operations
ENV SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt \
    REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt \
    NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ca-certificates.crt \
    CURL_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt

# Install base dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    bash \
    curl \
    git \
    python3 \
    python3-pip \
    gnupg \
    unzip \
    zsh \
    nano \
    openssh-client \
    build-essential \
    libffi-dev \
    libssl-dev \
    locales && \
    rm -rf /var/lib/apt/lists/*

# Configure locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && \
    locale-gen

ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8

ENV ZSH=/root/.oh-my-zsh \
    ZSH_CUSTOM=/root/.oh-my-zsh/custom

# zsh as default shell
RUN chsh -s $(which zsh)

# Install oh-my-zsh
RUN RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" \
    && mkdir -p "$ZSH_CUSTOM/themes" \
    && git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions" \
    && git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" \
    && git clone https://github.com/spaceship-prompt/spaceship-prompt.git "$ZSH_CUSTOM/themes/spaceship-prompt" --depth=1 \
    && ln -s "$ZSH_CUSTOM/themes/spaceship-prompt/spaceship.zsh-theme" "$ZSH_CUSTOM/themes/spaceship.zsh-theme"


# Install Azure CLI
RUN curl -sL https://aka.ms/InstallAzureCLIDeb | bash

# Install Ansible and ansible-lint
RUN pip3 install --break-system-packages ansible ansible-lint

# Install OpenTofu
RUN OPENTOFU_VERSION="1.6.0" && \
    wget -O /tmp/tofu.deb "https://github.com/opentofu/opentofu/releases/download/v${OPENTOFU_VERSION}/tofu_${OPENTOFU_VERSION}_amd64.deb" && \
    dpkg -i /tmp/tofu.deb && \
    rm /tmp/tofu.deb

# Install D2
curl -fsSL https://d2lang.com/install.sh | sh -s --

# Set working directory
WORKDIR /workspace

# Default shell
CMD ["/bin/bash"]
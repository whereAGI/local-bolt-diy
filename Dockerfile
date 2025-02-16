FROM ubuntu:22.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install Node.js 18.x (LTS)
RUN apt-get update && apt-get install -y ca-certificates curl gnupg && \
    mkdir -p /etc/apt/keyrings && \
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_18.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list

# Install essential packages
RUN apt-get update && apt-get install -y \
    nodejs \
    git \
    wget \
    python3 \
    python3-pip \
    sudo \
    vim \
    systemd \
    && rm -rf /var/lib/apt/lists/*

# Install code-server
RUN curl -fsSL https://code-server.dev/install.sh | sh

# Install Ollama
RUN curl -fsSL https://ollama.com/install.sh | sh && \
    mkdir -p /etc/systemd/system && \
    echo '[Unit]\n\
Description=Ollama Service\n\
After=network-online.target\n\
\n\
[Service]\n\
ExecStart=/usr/local/bin/ollama serve\n\
User=root\n\
Restart=always\n\
\n\
[Install]\n\
WantedBy=multi-user.target' > /etc/systemd/system/ollama.service && \
    systemctl enable ollama.service

# Install bolt.diy
RUN npm install -g bolt.diy

# Create a non-root user with sudo privileges
RUN useradd -m -s /bin/bash coder && \
    echo "coder ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/nopasswd

# Switch to the non-root user
USER coder
WORKDIR /home/coder

# Expose necessary ports
EXPOSE 8080 11434 3000

# Create startup script with proper service management
RUN echo '#!/bin/bash\n\
# Start Ollama\n\
sudo ollama serve &\n\
sleep 5\n\
\n\
# Start code-server\n\
code-server --bind-addr 0.0.0.0:8080 --auth password &\n\
\n\
# Start bolt.diy\n\
export NODE_OPTIONS="--experimental-modules"\n\
bolt.diy serve --host 0.0.0.0 --port 3000\n\
' > /home/coder/start.sh && \
    chmod +x /home/coder/start.sh

CMD ["/home/coder/start.sh"]
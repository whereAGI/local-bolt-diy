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
    openssl \
    && rm -rf /var/lib/apt/lists/*

# Set up Node.js global permissions
RUN mkdir -p /usr/local/lib/node_modules && \
    chmod -R 777 /usr/local/lib/node_modules && \
    npm config set prefix /usr/local

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

# Create a non-root user with sudo privileges
RUN useradd -m -s /bin/bash coder && \
    echo "coder ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/nopasswd

# Create SSL certificate for code-server
RUN mkdir -p /home/coder/.config/code-server/certificates && \
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /home/coder/.config/code-server/certificates/key.pem \
    -out /home/coder/.config/code-server/certificates/cert.pem \
    -subj "/C=US/ST=State/L=City/O=Organization/CN=localhost"

# Switch to the non-root user
USER coder
WORKDIR /home/coder

# Install bolt.diy with proper permissions
RUN mkdir -p /home/coder/.npm-global && \
    npm config set prefix '/home/coder/.npm-global' && \
    export PATH=/home/coder/.npm-global/bin:$PATH && \
    echo 'export PATH=/home/coder/.npm-global/bin:$PATH' >> /home/coder/.bashrc && \
    npm install -g bolt.diy

# Set up Ollama model directory
RUN sudo mkdir -p /root/.ollama/models && \
    sudo chown -R coder:coder /root/.ollama

# Expose necessary ports
EXPOSE 8080 11434 3000

# Create startup script with proper service management
RUN echo '#!/bin/bash\n\
# Start Ollama\n\
sudo ollama serve &\n\
\n\
# Wait for Ollama to start\n\
echo "Waiting for Ollama to start..."\n\
until curl -s http://localhost:11434/api/tags >/dev/null; do\n\
    sleep 1\n\
done\n\
\n\
# Pull the default model\n\
echo "Pulling Mistral model..."\n\
sudo ollama pull mistral\n\
\n\
# Start code-server with SSL\n\
code-server --bind-addr 0.0.0.0:8080 \\\n\
           --auth password \\\n\
           --cert /home/coder/.config/code-server/certificates/cert.pem \\\n\
           --cert-key /home/coder/.config/code-server/certificates/key.pem &\n\
\n\
# Set Node.js environment\n\
export PATH=/home/coder/.npm-global/bin:$PATH\n\
export NODE_OPTIONS="--experimental-modules"\n\
export WRANGLER_TMPDIR="/home/coder/.wrangler/tmp"\n\
\n\
# Create Wrangler temporary directory\n\
mkdir -p $WRANGLER_TMPDIR\n\
\n\
# Start bolt.diy\n\
bolt.diy serve --host 0.0.0.0 --port 3000\n\
' > /home/coder/start.sh && \
    chmod +x /home/coder/start.sh

CMD ["/home/coder/start.sh"]
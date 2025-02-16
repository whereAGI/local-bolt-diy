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

# Create a non-root user with sudo privileges
RUN useradd -m -s /bin/bash coder && \
    echo "coder ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/nopasswd

# Set up proper directories and permissions
RUN mkdir -p /usr/lib/node_modules && \
    mkdir -p /home/coder/.npm-global && \
    mkdir -p /home/coder/.wrangler/tmp && \
    mkdir -p /root/.ollama/models && \
    mkdir -p /home/coder/.config/code-server/certificates && \
    chown -R coder:coder /home/coder/.npm-global && \
    chown -R coder:coder /home/coder/.wrangler && \
    chown -R coder:coder /home/coder/.config && \
    chown -R coder:coder /usr/lib/node_modules && \
    chmod -R 777 /usr/lib/node_modules && \
    chmod -R 777 /home/coder/.wrangler && \
    chown -R coder:coder /root/.ollama

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
WantedBy=multi-user.target' > /etc/systemd/system/ollama.service

# Create SSL certificate for code-server
RUN openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /home/coder/.config/code-server/certificates/key.pem \
    -out /home/coder/.config/code-server/certificates/cert.pem \
    -subj "/C=US/ST=State/L=City/O=Organization/CN=localhost" && \
    chown -R coder:coder /home/coder/.config/code-server/certificates

# Switch to the non-root user
USER coder
WORKDIR /home/coder

# Configure npm and install bolt.diy
RUN npm config set prefix '/home/coder/.npm-global' && \
    export PATH=/home/coder/.npm-global/bin:$PATH && \
    echo 'export PATH=/home/coder/.npm-global/bin:$PATH' >> /home/coder/.bashrc && \
    npm install -g bolt.diy

# Expose necessary ports
EXPOSE 8080 11434 3000

# Create startup script with proper service management
RUN echo '#!/bin/bash\n\
# Set Node.js environment\n\
export PATH=/home/coder/.npm-global/bin:$PATH\n\
export NODE_OPTIONS="--experimental-modules"\n\
export WRANGLER_TMPDIR="/home/coder/.wrangler/tmp"\n\
\n\
# Start Ollama\n\
echo "Starting Ollama service..."\n\
sudo ollama serve &\n\
\n\
# Wait for Ollama to fully start\n\
echo "Waiting for Ollama to initialize..."\n\
while ! curl -s http://localhost:11434/api/tags >/dev/null; do\n\
    sleep 2\n\
    echo "Still waiting for Ollama..."\n\
done\n\
echo "Ollama is ready!"\n\
\n\
# Pull the model\n\
echo "Pulling deepseek-r1:1.5b model..."\n\
sudo ollama pull deepseek-r1:1.5b\n\
\n\
# Start code-server with SSL\n\
echo "Starting code-server..."\n\
code-server --bind-addr 0.0.0.0:8080 \\\n\
           --auth password \\\n\
           --cert /home/coder/.config/code-server/certificates/cert.pem \\\n\
           --cert-key /home/coder/.config/code-server/certificates/key.pem &\n\
\n\
# Ensure Wrangler directory exists and has correct permissions\n\
mkdir -p $WRANGLER_TMPDIR\n\
chmod -R 777 $WRANGLER_TMPDIR\n\
\n\
# Start bolt.diy\n\
echo "Starting bolt.diy..."\n\
bolt.diy serve --host 0.0.0.0 --port 3000\n\
' > /home/coder/start.sh && \
    chmod +x /home/coder/start.sh

CMD ["/home/coder/start.sh"]
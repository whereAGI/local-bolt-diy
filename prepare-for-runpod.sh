#!/bin/bash

# Pull required images
docker pull linuxserver/code-server:latest
docker pull ollama/ollama:latest
docker pull ghcr.io/stackblitz-labs/bolt.diy:latest

# Create a new image that includes all three services
cat > Dockerfile.runpod << 'EOL'
FROM ubuntu:22.04

# Install Docker
RUN apt-get update && apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release && \
    mkdir -p /etc/apt/keyrings && \
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null && \
    apt-get update && \
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Copy necessary files
COPY docker-compose.yml /app/
COPY .env /app/
WORKDIR /app

# Create workspace directory
RUN mkdir -p workspace

# Start script
RUN echo '#!/bin/bash\n\
service docker start\n\
sleep 5\n\
cd /app\n\
docker compose up' > /start.sh && \
    chmod +x /start.sh

CMD ["/start.sh"]
EOL

# Build the RunPod image
docker build -t pratheek1994/local-bolt-diy:latest -f Dockerfile.runpod .

# Push to Docker Hub
docker push pratheek1994/local-bolt-diy:latest
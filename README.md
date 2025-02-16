# Local bolt.diy Development Environment

This project sets up a local development environment combining bolt.diy, Code-server (VS Code in browser), and Ollama in a Docker container. It's designed to be run either locally or on RunPod.io.

## Version
Current version: 1.0.0

## Components

- bolt.diy: AI-powered development environment
- Code-server: VS Code in the browser
- Ollama: Local LLM server

## Prerequisites

- Docker
- Docker Compose (for local development)
- Git (optional)

## RunPod.io Deployment

1. Pull the image:
   ```bash
   docker pull pratheek1994/local-bolt-diy:latest
   ```

2. On RunPod.io:
   - Create a new pod
   - Use the image: `pratheek1994/local-bolt-diy:latest`
   - Set environment variables:
     ```
     PASSWORD=your_secure_password
     OLLAMA_HOST=0.0.0.0
     OLLAMA_ORIGINS=*
     NODE_OPTIONS=--experimental-modules
     ```
   - Expose ports: 8080, 11434, and 3000

## Accessing Services

- Code-server: http://[your-pod-url]:8080
- bolt.diy: http://[your-pod-url]:3000
- Ollama API: http://[your-pod-url]:11434

## Environment Variables

- `PASSWORD`: Password for Code-server access
- `OLLAMA_HOST`: Ollama server host (default: 0.0.0.0)
- `OLLAMA_ORIGINS`: Allowed origins for Ollama
- `NODE_OPTIONS`: Node.js options for experimental features

## Maintenance

To update the environment:
```bash
docker-compose pull
docker-compose up -d --build
```

## Troubleshooting

1. If services don't start:
   - Check the container logs: `docker logs local-bolt-diy`
   - Verify all ports are correctly exposed
   - Ensure environment variables are set correctly

2. If Ollama is not accessible:
   - Check if the service is running: `docker exec local-bolt-diy sudo systemctl status ollama`
   - Verify the OLLAMA_HOST setting

3. If bolt.diy doesn't connect to Ollama:
   - Verify the OLLAMA_ORIGINS setting
   - Check network connectivity between services

## License

MIT
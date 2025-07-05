# flake2docker

🐋 A powerful CLI tool to build Docker containers from Nix flake devShells without modifying your flake.nix files.

## Features

- 🚀 **Build Docker images from any Nix flake devShell**
- 🎯 **Zero modification** to your existing flake.nix files
- 🔧 **Two CLI variants**: basic and advanced with extensive configuration options
- 📦 **Layered images** for better caching and smaller layers
- 🌐 **Multi-platform support** (cross-system builds)
- 🏗️ **Registry integration** with push/pull capabilities
- 🔐 **Proper user management** and permissions
- 📊 **Verbose logging** and debugging support
- 🎨 **Customizable** image configuration (ports, volumes, environment variables)

## Quick Start

```bash
# Install flake2docker
nix profile install github:conneroisu/flake2docker

# Build and load Docker image from current directory's flake
flake2docker --load

# Run the container
docker run -it --rm -v $(pwd):/workspace flake-devshell:latest
```

## Installation

### Using Nix Profile

```bash
nix profile install github:conneroisu/flake2docker
```

### Using Nix Run (one-time usage)

```bash
nix run github:conneroisu/flake2docker -- --help
```

### Adding to Your Flake

Add flake2docker as an input to your `flake.nix`:

```nix
{
  description = "Your project description";
  
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake2docker.url = "github:conneroisu/flake2docker";
  };
  
  outputs = { self, nixpkgs, flake2docker, ... }:
    let
      system = "x86_64-linux"; # or your target system
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      # Include flake2docker in your devShell
      devShells.default = pkgs.mkShell {
        buildInputs = [
          flake2docker.packages.${system}.flake2docker
          flake2docker.packages.${system}.flake2docker-advanced
          # your other dependencies...
        ];
      };
      
      # Or make it available as a package
      packages = {
        inherit (flake2docker.packages.${system}) flake2docker flake2docker-advanced;
      };
    };
}
```

### Adding to NixOS Configuration

```nix
# configuration.nix or flake-based NixOS
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake2docker.url = "github:conneroisu/flake2docker";
  };

  outputs = { nixpkgs, flake2docker, ... }: {
    nixosConfigurations.yourhostname = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        {
          environment.systemPackages = [
            flake2docker.packages.x86_64-linux.flake2docker
            flake2docker.packages.x86_64-linux.flake2docker-advanced
          ];
        }
      ];
    };
  };
}
```

### Adding to Home Manager

```nix
# home.nix
{ inputs, pkgs, ... }: {
  home.packages = [
    inputs.flake2docker.packages.${pkgs.system}.flake2docker
    inputs.flake2docker.packages.${pkgs.system}.flake2docker-advanced
  ];
}
```

### Development Installation

```bash
git clone https://github.com/conneroisu/flake2docker.git
cd flake2docker
nix develop
```

## Usage

### Basic CLI: `flake2docker`

```bash
# Build from current directory
flake2docker --load

# Build from specific flake
flake2docker -f /path/to/flake --name myapp --tag v1.0 --load

# Build from GitHub repository
flake2docker -f github:owner/repo --load

# Build and save to file
flake2docker -f . --output myapp.tar

# Build for different system
flake2docker -s x86_64-linux --load
```

### Advanced CLI: `flake2docker-advanced`

```bash
# Build layered image with custom configuration
flake2docker-advanced \
    --layered \
    --port 3000 \
    --port 8080 \
    --env NODE_ENV=production \
    --volume /app/data \
    --load

# Build and push to registry
flake2docker-advanced \
    --name myapp \
    --tag v1.0 \
    --registry docker.io/username \
    --push

# Note: Multi-architecture builds require Docker buildx
# flake2docker-advanced \
#     --platform linux/amd64,linux/arm64 \
#     --registry ghcr.io/username/myapp \
#     --push

# Note: Caching features are planned for future releases
# flake2docker-advanced \
#     --cache-from type=registry,ref=myapp:cache \
#     --cache-to type=registry,ref=myapp:cache,mode=max \
#     --push
```

## Command Line Options

### Basic Options (both CLIs)

| Option | Description | Default |
|--------|-------------|---------|
| `-f, --flake PATH` | Path to flake | `.` (current directory) |
| `-n, --name NAME` | Docker image name | `flake-devshell` |
| `-t, --tag TAG` | Docker image tag | `latest` |
| `-s, --system SYSTEM` | Target system | Current system |
| `-l, --load` | Load image into Docker | `false` |
| `-o, --output FILE` | Save image to file | - |
| `-v, --verbose` | Enable verbose output | `false` |
| `-h, --help` | Show help message | - |

### Advanced Options (flake2docker-advanced only)

| Option | Description | Default |
|--------|-------------|---------|
| `-d, --devshell NAME` | DevShell name | `default` |
| `--layered` | Use buildLayeredImage | `false` |
| `--registry URL` | Registry URL | - |
| `--push` | Push to registry | `false` |
| `--platform PLATFORM` | Target platform (future feature) | - |
| `--cache-from SOURCE` | Cache source (future feature) | - |
| `--cache-to DEST` | Cache destination (future feature) | - |
| `--build-arg KEY=VALUE` | Build arguments | - |
| `--label KEY=VALUE` | Image labels | - |
| `--volume PATH` | Volume mount points | - |
| `--port PORT` | Exposed ports | - |
| `--env KEY=VALUE` | Environment variables | - |
| `--entrypoint CMD` | Container entrypoint | - |
| `--cmd CMD` | Container command | - |
| `--user USER` | Container user | `nixuser` |
| `--workdir PATH` | Working directory | `/workspace` |

## Examples

### Example 1: Basic Development Environment

```bash
# Create a simple flake
cat > flake.nix << EOF
{
  description = "Development environment";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  inputs.flake-utils.url = "github:numtide/flake-utils";
  
  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system: {
      devShells.default = nixpkgs.legacyPackages.\${system}.mkShell {
        buildInputs = with nixpkgs.legacyPackages.\${system}; [
          nodejs_20
          python3
          git
        ];
        shellHook = ''
          echo "Welcome to the development environment!"
        '';
      };
    });
}
EOF

# Build and run
flake2docker --load
docker run -it --rm -v $(pwd):/workspace flake-devshell:latest
```

### Example 2: Web Application with Exposed Ports

```bash
flake2docker-advanced \
    --name webapp \
    --tag latest \
    --port 3000 \
    --port 8080 \
    --env NODE_ENV=development \
    --volume /app/uploads \
    --load

# Run with port mapping
docker run -it --rm \
    -p 3000:3000 \
    -p 8080:8080 \
    -v $(pwd):/workspace \
    -v webapp_uploads:/app/uploads \
    webapp:latest
```

### Example 3: Registry Build with Labels

```bash
flake2docker-advanced \
    --name myproject \
    --tag v1.0.0 \
    --registry ghcr.io/username \
    --layered \
    --label "org.opencontainers.image.source=https://github.com/username/myproject" \
    --label "org.opencontainers.image.version=v1.0.0" \
    --push
```

### Example 4: Development Environment with Custom DevShell

```bash
# If your flake has multiple devShells
flake2docker-advanced \
    --devshell backend \
    --name myapp-backend \
    --port 8000 \
    --env DATABASE_URL=postgresql://localhost/myapp \
    --load

# Or for frontend
flake2docker-advanced \
    --devshell frontend \
    --name myapp-frontend \
    --port 3000 \
    --env API_URL=http://localhost:8000 \
    --load
```

## Integration Examples

### Docker Compose

```yaml
version: '3.8'
services:
  app:
    image: myapp:latest
    ports:
      - "3000:3000"
    volumes:
      - .:/workspace
      - app_data:/app/data
    environment:
      - NODE_ENV=development
    command: npm run dev

volumes:
  app_data:
```

### GitHub Actions

```yaml
name: Build and Push Docker Image

on:
  push:
    branches: [ main ]
    tags: [ 'v*' ]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    
    - uses: cachix/install-nix-action@v22
      with:
        nix_path: nixpkgs=channel:nixos-unstable
    
    - name: Build and push Docker image
      run: |
        nix run github:conneroisu/flake2docker#flake2docker-advanced -- \
          --name myapp \
          --tag ${GITHUB_REF#refs/tags/} \
          --registry ghcr.io/${{ github.repository_owner }} \
          --layered \
          --push
      env:
        DOCKER_REGISTRY_USER: ${{ github.actor }}
        DOCKER_REGISTRY_PASSWORD: ${{ secrets.GITHUB_TOKEN }}
```

### Makefile Integration

```makefile
.PHONY: docker-build docker-run docker-push

IMAGE_NAME ?= myapp
IMAGE_TAG ?= latest
REGISTRY ?= docker.io/username

docker-build:
	flake2docker-advanced \
		--name $(IMAGE_NAME) \
		--tag $(IMAGE_TAG) \
		--layered \
		--load

docker-run:
	docker run -it --rm \
		-p 3000:3000 \
		-v $(PWD):/workspace \
		$(IMAGE_NAME):$(IMAGE_TAG)

docker-push:
	flake2docker-advanced \
		--name $(IMAGE_NAME) \
		--tag $(IMAGE_TAG) \
		--registry $(REGISTRY) \
		--layered \
		--push

docker-dev: docker-build docker-run
```

## How It Works

1. **Flake Evaluation**: The CLI uses `builtins.getFlake` to dynamically load and evaluate your flake
2. **DevShell Extraction**: Extracts the specified devShell (default: `default`) from the flake outputs
3. **Package Collection**: Collects all `buildInputs` from the devShell
4. **Image Building**: Uses `dockerTools.buildImage` or `dockerTools.buildLayeredImage` to create the container
5. **Environment Setup**: Preserves environment variables, shell hooks, and PATH configuration
6. **User Management**: Creates a proper non-root user with appropriate permissions

## Architecture

The project consists of:

- **`flake.nix`**: Main flake definition with package outputs and dev shell
- **`src/flake2docker.sh`**: Basic CLI implementation
- **`src/flake2docker-advanced.sh`**: Advanced CLI with extensive features
- **`examples/`**: Example flake configurations and usage patterns
- **`tests/`**: Test suites for validation

## Troubleshooting

### Common Issues

1. **"No devShell found"**: Ensure your flake has a `devShells.default` output
2. **Docker daemon not running**: Start Docker service before building
3. **Permission denied**: Ensure your user is in the docker group
4. **Build failures**: Use `--verbose` flag for detailed error messages

### Debug Commands

```bash
# Check flake structure
nix flake show

# Validate flake
nix flake check

# Test devShell manually
nix develop

# Build with verbose output
flake2docker --verbose --load
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests: `make test`
5. Submit a pull request

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Related Projects

- [nixpkgs dockerTools](https://nixos.org/manual/nixpkgs/stable/#sec-pkgs-dockerTools)
- [nix2container](https://github.com/nlewo/nix2container)
- [flake-utils](https://github.com/numtide/flake-utils)

## Changelog

### v1.0.0
- Initial release with basic and advanced CLI tools
- Support for layered images and multi-architecture builds
- Registry integration with push/pull capabilities
- Comprehensive documentation and examples
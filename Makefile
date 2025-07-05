# flake2docker Makefile

.PHONY: help build test clean install examples docker-build docker-run demo

# Default target
help:
	@echo "🐋 flake2docker - Build Docker containers from Nix flake devShells"
	@echo ""
	@echo "Available targets:"
	@echo "  help           - Show this help message"
	@echo "  build          - Build the flake2docker CLI tools"
	@echo "  test           - Run tests and validation"
	@echo "  clean          - Clean build artifacts"
	@echo "  install        - Install flake2docker to user profile"
	@echo "  examples       - Run example builds"
	@echo "  docker-build   - Build Docker image from current flake"
	@echo "  docker-run     - Run Docker container from current flake"
	@echo "  demo           - Run full demonstration"
	@echo "  format         - Format code"
	@echo "  lint           - Run linting"
	@echo ""
	@echo "Variables:"
	@echo "  IMAGE_NAME     - Docker image name (default: flake2docker-demo)"
	@echo "  IMAGE_TAG      - Docker image tag (default: latest)"
	@echo "  EXAMPLE        - Example to build (default: basic-devenv)"

# Configuration
IMAGE_NAME ?= flake2docker-demo
IMAGE_TAG ?= latest
EXAMPLE ?= basic-devenv

# Build the flake2docker CLI tools
build:
	@echo "🔨 Building flake2docker CLI tools..."
	nix build .#flake2docker
	nix build .#flake2docker-advanced
	@echo "✅ Built flake2docker CLI tools"

# Run tests and validation
test:
	@echo "🧪 Running tests..."
	@echo "1. Checking flake validity..."
	nix flake check
	@echo "2. Testing basic CLI..."
	nix run .#flake2docker -- --help
	@echo "3. Testing advanced CLI..."
	nix run .#flake2docker-advanced -- --help
	@echo "4. Testing shell scripts..."
	shellcheck src/flake2docker.sh
	shellcheck src/flake2docker-advanced.sh
	@echo "5. Testing example flakes..."
	nix flake check examples/basic-devenv.nix
	nix flake check examples/multi-devshells.nix
	nix flake check examples/web-app.nix
	@echo "✅ All tests passed!"

# Clean build artifacts
clean:
	@echo "🧹 Cleaning build artifacts..."
	rm -rf result*
	rm -rf .direnv
	docker system prune -f
	@echo "✅ Cleaned build artifacts"

# Install flake2docker to user profile
install:
	@echo "📦 Installing flake2docker to user profile..."
	nix profile install .#flake2docker
	nix profile install .#flake2docker-advanced
	@echo "✅ Installed flake2docker CLI tools"
	@echo "You can now use 'flake2docker' and 'flake2docker-advanced' commands"

# Run example builds
examples:
	@echo "🎯 Building example Docker images..."
	@echo "1. Building basic development environment..."
	nix run .#flake2docker -- -f examples/basic-devenv.nix -n basic-devenv -t demo --load
	@echo "2. Building web application environment..."
	nix run .#flake2docker-advanced -- -f examples/web-app.nix -n web-app -t demo --port 3000 --load
	@echo "3. Building frontend environment from multi-devshells..."
	nix run .#flake2docker-advanced -- -f examples/multi-devshells.nix -d frontend -n frontend-env -t demo --load
	@echo "✅ Built example Docker images"
	@echo "Available images:"
	@docker images | grep -E "(basic-devenv|web-app|frontend-env)" | head -10

# Build Docker image from current flake
docker-build:
	@echo "🐳 Building Docker image from current flake..."
	nix run .#flake2docker-advanced -- -n $(IMAGE_NAME) -t $(IMAGE_TAG) --layered --load
	@echo "✅ Built Docker image: $(IMAGE_NAME):$(IMAGE_TAG)"

# Run Docker container
docker-run:
	@echo "🚀 Running Docker container..."
	docker run -it --rm -v $(PWD):/workspace $(IMAGE_NAME):$(IMAGE_TAG)

# Run full demonstration
demo:
	@echo "🎪 Running flake2docker demonstration..."
	@echo "================================"
	make examples
	@echo ""
	@echo "🎯 Demonstration complete!"
	@echo "Available images:"
	@docker images | grep -E "(basic-devenv|web-app|frontend-env|flake2docker)" | head -10
	@echo ""
	@echo "Try running an example:"
	@echo "  docker run -it --rm -v \$$(pwd):/workspace basic-devenv:demo"
	@echo "  docker run -it --rm -p 3000:3000 -v \$$(pwd):/workspace web-app:demo"
	@echo "  docker run -it --rm -v \$$(pwd):/workspace frontend-env:demo"

# Format code
format:
	@echo "🎨 Formatting code..."
	nix fmt
	@echo "✅ Code formatted"

# Run linting
lint:
	@echo "🔍 Running linting..."
	shellcheck src/*.sh
	nix flake check
	@echo "✅ Linting complete"

# Development shell
dev:
	@echo "🚀 Entering development shell..."
	nix develop

# Show project structure
tree:
	@echo "📁 Project structure:"
	@tree -I 'result*|.direnv|.git' || ls -la
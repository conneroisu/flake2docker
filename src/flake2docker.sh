#!/usr/bin/env bash

set -euo pipefail

# Default values
FLAKE_PATH="."
IMAGE_NAME="flake-devshell"
TAG="latest"
SYSTEM="$(nix eval --impure --raw --expr 'builtins.currentSystem')"
LOAD_IMAGE=false
SAVE_TO=""
VERBOSE=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_verbose() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${BLUE}[DEBUG]${NC} $1"
    fi
}

# Help function
show_help() {
    cat << EOF
flake2docker - Build Docker containers from Nix flake devShells

USAGE:
    flake2docker [OPTIONS]

OPTIONS:
    -f, --flake PATH        Path to flake (default: current directory)
    -n, --name NAME         Docker image name (default: flake-devshell)
    -t, --tag TAG           Docker image tag (default: latest)
    -s, --system SYSTEM     Target system (default: current system)
    -l, --load              Load image into Docker after building
    -o, --output FILE       Save image to file instead of loading
    -v, --verbose           Enable verbose output
    -h, --help              Show this help message

EXAMPLES:
    # Build Docker image from current directory flake
    flake2docker --load

    # Build from specific flake with custom name
    flake2docker -f /path/to/flake -n myapp -t v1.0 --load

    # Build and save to file
    flake2docker -f github:owner/repo -o myapp.tar

    # Build for different system
    flake2docker -s x86_64-linux --load

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--flake)
            FLAKE_PATH="$2"
            shift 2
            ;;
        -n|--name)
            IMAGE_NAME="$2"
            shift 2
            ;;
        -t|--tag)
            TAG="$2"
            shift 2
            ;;
        -s|--system)
            SYSTEM="$2"
            shift 2
            ;;
        -l|--load)
            LOAD_IMAGE=true
            shift
            ;;
        -o|--output)
            SAVE_TO="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Validate flake path
if [[ ! -f "$FLAKE_PATH/flake.nix" && ! "$FLAKE_PATH" =~ ^github: && ! "$FLAKE_PATH" =~ ^git\+ ]]; then
    log_error "No flake.nix found at $FLAKE_PATH"
    exit 1
fi

log_info "Building Docker image from flake: $FLAKE_PATH"
log_verbose "Target system: $SYSTEM"
log_verbose "Image name: $IMAGE_NAME:$TAG"

# Create temporary Nix expression for building the Docker image
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

cat > "$TEMP_DIR/docker-builder.nix" << EOF
{ pkgs ? import <nixpkgs> {} }:
let
  flake = builtins.getFlake "$FLAKE_PATH";
  
  # Try to get devShell from different possible locations
  devShell = 
    if builtins.hasAttr "devShells" flake && builtins.hasAttr "$SYSTEM" flake.devShells then
      if builtins.hasAttr "default" flake.devShells.$SYSTEM then
        flake.devShells.$SYSTEM.default
      else
        builtins.head (builtins.attrValues flake.devShells.$SYSTEM)
    else if builtins.hasAttr "devShell" flake && builtins.hasAttr "$SYSTEM" flake.devShell then
      flake.devShell.$SYSTEM
    else
      throw "No devShell found for system $SYSTEM in flake $FLAKE_PATH";
      
  # Extract packages from devShell
  shellPackages = devShell.buildInputs or [];
  
  # Get shell hook if available
  shellHook = devShell.shellHook or "";
  
  # Build the Docker image
in pkgs.dockerTools.buildImage {
  name = "$IMAGE_NAME";
  tag = "$TAG";
  
  contents = with pkgs; [
    bashInteractive
    coreutils
    findutils
    gnugrep
    gnused
    gawk
    which
    procps
    util-linux
  ] ++ shellPackages;
  
  config = {
    Cmd = [ "\${pkgs.bashInteractive}/bin/bash" ];
    WorkingDir = "/workspace";
    Env = [
      "PATH=\${pkgs.lib.makeBinPath ([ pkgs.bashInteractive pkgs.coreutils pkgs.findutils pkgs.gnugrep pkgs.gnused pkgs.gawk pkgs.which pkgs.procps pkgs.util-linux ] ++ shellPackages)}"
      "TERM=xterm-256color"
    ];
    User = "1000:1000";
    ExposedPorts = {
      "8080/tcp" = {};
    };
    Volumes = {
      "/workspace" = {};
    };
  };
  
  runAsRoot = '''
    #!$\{pkgs.runtimeShell}
    mkdir -p /workspace
    chmod 1777 /workspace
    
    # Create a non-root user
    groupadd -r nixuser --gid=1000
    useradd -r -g nixuser --uid=1000 --home-dir=/workspace --shell=$\{pkgs.bashInteractive}/bin/bash nixuser
    
    # Set up shell environment
    echo 'export PS1="[flake2docker] \u@\h:\w\$ "' >> /workspace/.bashrc
    echo 'cd /workspace' >> /workspace/.bashrc
    
    # Add shell hook if available
    if [[ -n "${shellHook:-}" ]]; then
      echo "${shellHook:-}" >> /workspace/.bashrc
    fi
    
    chown -R nixuser:nixuser /workspace
  ''';
}
EOF

log_verbose "Created Docker builder expression at $TEMP_DIR/docker-builder.nix"

# Build the Docker image
log_info "Building Docker image..."
if [[ "$VERBOSE" == "true" ]]; then
    RESULT=$(nix-build "$TEMP_DIR/docker-builder.nix" --no-out-link)
else
    RESULT=$(nix-build "$TEMP_DIR/docker-builder.nix" --no-out-link 2>/dev/null)
fi

if [[ -n "$RESULT" ]]; then
    log_success "Docker image built successfully: $RESULT"
    
    # Load image into Docker or save to file
    if [[ "$LOAD_IMAGE" == "true" ]]; then
        log_info "Loading image into Docker..."
        docker load < "$RESULT"
        log_success "Image loaded: $IMAGE_NAME:$TAG"
        
        # Show image info
        docker images "$IMAGE_NAME:$TAG"
        
        log_info "You can now run the container with:"
        echo "  docker run -it --rm -v \$(pwd):/workspace $IMAGE_NAME:$TAG"
        
    elif [[ -n "$SAVE_TO" ]]; then
        log_info "Saving image to file: $SAVE_TO"
        cp "$RESULT" "$SAVE_TO"
        log_success "Image saved to: $SAVE_TO"
        
    else
        log_info "Image built but not loaded. Use --load to load into Docker or --output to save to file."
        log_info "Image path: $RESULT"
    fi
else
    log_error "Failed to build Docker image"
    exit 1
fi
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
LAYERED=false
DEVSHELL_NAME="default"
REGISTRY=""
PUSH=false
export PLATFORM=""  # Future feature
export CACHE_FROM=""  # Future feature
export CACHE_TO=""  # Future feature
BUILD_ARGS=()
LABELS=()
VOLUMES=()
PORTS=()
ENV_VARS=()
ENTRYPOINT=""
CMD=""
USER=""
WORKDIR="/workspace"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
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

log_step() {
    echo -e "${PURPLE}[STEP]${NC} $1"
}

# Help function
show_help() {
    cat << EOF
flake2docker-advanced - Advanced Docker container builder for Nix flake devShells

USAGE:
    flake2docker-advanced [OPTIONS]

BASIC OPTIONS:
    -f, --flake PATH        Path to flake (default: current directory)
    -n, --name NAME         Docker image name (default: flake-devshell)
    -t, --tag TAG           Docker image tag (default: latest)
    -s, --system SYSTEM     Target system (default: current system)
    -d, --devshell NAME     DevShell name (default: default)
    -l, --load              Load image into Docker after building
    -o, --output FILE       Save image to file instead of loading
    -v, --verbose           Enable verbose output
    -h, --help              Show this help message

ADVANCED OPTIONS:
    --layered               Use buildLayeredImage for better caching
    --registry URL          Registry URL for pushing (e.g., docker.io/user)
    --push                  Push image to registry after building
    --platform PLATFORM    Target platform (e.g., linux/amd64,linux/arm64)
    --cache-from SOURCE     Cache source (e.g., type=registry,ref=...)
    --cache-to DEST         Cache destination
    --build-arg KEY=VALUE   Build arguments
    --label KEY=VALUE       Image labels
    --volume PATH           Volume mount points
    --port PORT             Exposed ports
    --env KEY=VALUE         Environment variables
    --entrypoint CMD        Container entrypoint
    --cmd CMD               Container command
    --user USER             Container user
    --workdir PATH          Working directory (default: /workspace)

EXAMPLES:
    # Basic usage
    flake2docker-advanced --load

    # Build layered image with custom devShell
    flake2docker-advanced -d development --layered --load

    # Build and push to registry
    flake2docker-advanced -n myapp -t v1.0 --registry docker.io/user --push

    # Build with custom configuration
    flake2docker-advanced --layered --port 3000 --port 8080 \\
        --env NODE_ENV=production --volume /app/data --load

    # Multi-architecture build
    flake2docker-advanced --platform linux/amd64,linux/arm64 --push

    # Build with caching
    flake2docker-advanced --cache-from type=registry,ref=myapp:cache \\
        --cache-to type=registry,ref=myapp:cache,mode=max --push

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
        -d|--devshell)
            DEVSHELL_NAME="$2"
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
        --layered)
            LAYERED=true
            shift
            ;;
        --registry)
            REGISTRY="$2"
            shift 2
            ;;
        --push)
            PUSH=true
            shift
            ;;
        --platform)
            PLATFORM="$2"
            shift 2
            ;;
        --cache-from)
            CACHE_FROM="$2"
            shift 2
            ;;
        --cache-to)
            CACHE_TO="$2"
            shift 2
            ;;
        --build-arg)
            BUILD_ARGS+=("$2")
            shift 2
            ;;
        --label)
            LABELS+=("$2")
            shift 2
            ;;
        --volume)
            VOLUMES+=("$2")
            shift 2
            ;;
        --port)
            PORTS+=("$2")
            shift 2
            ;;
        --env)
            ENV_VARS+=("$2")
            shift 2
            ;;
        --entrypoint)
            ENTRYPOINT="$2"
            shift 2
            ;;
        --cmd)
            CMD="$2"
            shift 2
            ;;
        --user)
            USER="$2"
            shift 2
            ;;
        --workdir)
            WORKDIR="$2"
            shift 2
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

# Validate inputs
if [[ ! -f "$FLAKE_PATH/flake.nix" && ! "$FLAKE_PATH" =~ ^github: && ! "$FLAKE_PATH" =~ ^git\+ ]]; then
    log_error "No flake.nix found at $FLAKE_PATH"
    exit 1
fi

if [[ "$PUSH" == "true" && -z "$REGISTRY" ]]; then
    log_error "Registry must be specified when pushing"
    exit 1
fi

# Set full image name with registry if pushing
if [[ -n "$REGISTRY" ]]; then
    FULL_IMAGE_NAME="${REGISTRY}/${IMAGE_NAME}"
else
    FULL_IMAGE_NAME="$IMAGE_NAME"
fi

log_step "Configuration Summary"
log_info "Flake path: $FLAKE_PATH"
log_info "DevShell: $DEVSHELL_NAME"
log_info "Target system: $SYSTEM"
log_info "Image name: $FULL_IMAGE_NAME:$TAG"
log_info "Layered build: $LAYERED"
log_info "Push to registry: $PUSH"

# Create temporary Nix expression for building the Docker image
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

# Generate exposed ports configuration
EXPOSED_PORTS=""
if [[ ${#PORTS[@]} -gt 0 ]]; then
    for port in "${PORTS[@]}"; do
        EXPOSED_PORTS+="\n      \"$port/tcp\" = {};"
    done
fi

# Generate volume configuration
VOLUME_CONFIG=""
if [[ ${#VOLUMES[@]} -gt 0 ]]; then
    for volume in "${VOLUMES[@]}"; do
        VOLUME_CONFIG+="\n      \"$volume\" = {};"
    done
fi

# Generate environment variables
ENV_CONFIG=""
if [[ ${#ENV_VARS[@]} -gt 0 ]]; then
    for env in "${ENV_VARS[@]}"; do
        ENV_CONFIG+="\n      \"$env\""
    done
fi

# Generate labels
LABEL_CONFIG=""
if [[ ${#LABELS[@]} -gt 0 ]]; then
    for label in "${LABELS[@]}"; do
        LABEL_CONFIG+="\n      \"$label\""
    done
fi

# Choose build function
if [[ "$LAYERED" == "true" ]]; then
    BUILD_FUNCTION="buildLayeredImage"
else
    BUILD_FUNCTION="buildImage"
fi

# shellcheck disable=SC2154,SC2043
cat > "$TEMP_DIR/docker-builder.nix" << EOF
{ pkgs ? import <nixpkgs> {} }:
let
  flake = builtins.getFlake "$FLAKE_PATH";
  
  # Try to get devShell from different possible locations
  devShell = 
    if builtins.hasAttr "devShells" flake && builtins.hasAttr "$SYSTEM" flake.devShells then
      if builtins.hasAttr "$DEVSHELL_NAME" flake.devShells.$SYSTEM then
        flake.devShells.$SYSTEM.$DEVSHELL_NAME
      else
        throw "DevShell '$DEVSHELL_NAME' not found for system $SYSTEM in flake $FLAKE_PATH"
    else if builtins.hasAttr "devShell" flake && builtins.hasAttr "$SYSTEM" flake.devShell then
      flake.devShell.$SYSTEM
    else
      throw "No devShell found for system $SYSTEM in flake $FLAKE_PATH";
      
  # Extract packages from devShell
  shellPackages = devShell.buildInputs or [];
  
  # Get shell hook if available
  shellHook = devShell.shellHook or "";
  
  # Base system packages
  basePackages = with pkgs; [
    bashInteractive
    coreutils
    findutils
    gnugrep
    gnused
    gawk
    which
    procps
    util-linux
    curl
    wget
    git
    ca-certificates
  ];
  
  # All packages
  allPackages = basePackages ++ shellPackages;
  
  # Build the Docker image
in pkgs.dockerTools.$BUILD_FUNCTION {
  name = "$FULL_IMAGE_NAME";
  tag = "$TAG";
  
  contents = allPackages;
  
  config = {
    Cmd = if "$CMD" != "" then [ "$CMD" ] else [ "\${pkgs.bashInteractive}/bin/bash" ];
    $(if [[ -n "$ENTRYPOINT" ]]; then echo "Entrypoint = [ \"$ENTRYPOINT\" ];"; fi)
    WorkingDir = "$WORKDIR";
    User = ${if [[ -n "$USER" ]]; then "\"$USER\""; else "\"nixuser\""; fi};
    
    Env = [
      "PATH=\${pkgs.lib.makeBinPath allPackages}"
      "TERM=xterm-256color"
      "HOME=$WORKDIR"$ENV_CONFIG
    ];
    
    ${if [[ -n "$EXPOSED_PORTS" ]]; then echo -e "ExposedPorts = {$EXPOSED_PORTS\n    };"; fi}
    ${if [[ -n "$VOLUME_CONFIG" ]]; then echo -e "Volumes = {$VOLUME_CONFIG\n    };"; fi}
    ${if [[ -n "$LABEL_CONFIG" ]]; then echo -e "Labels = {$LABEL_CONFIG\n    };"; fi}
  };
  
  runAsRoot = '''
    #!$\{pkgs.runtimeShell}
    set -euo pipefail
    
    # Create directories
    mkdir -p $WORKDIR
    mkdir -p /tmp
    mkdir -p /home
    
    # Set permissions
    chmod 1777 /tmp
    chmod 755 $WORKDIR
    
    # Create user if not specified
    $(if [[ -z "$USER" ]]; then
      echo 'groupadd -r nixuser --gid=1000 || true'
      echo "useradd -r -g nixuser --uid=1000 --home-dir=$WORKDIR --shell=\${pkgs.bashInteractive}/bin/bash nixuser || true"
    fi)
    
    # Set up shell environment
    cat > $WORKDIR/.bashrc << 'BASHRC_EOF'
export PS1="[flake2docker] \u@\h:\w\$ "
export PATH=\${PATH}
cd $WORKDIR

# Shell hook from flake
${shellHook:-}

# Custom welcome message
echo "🐋 Welcome to flake2docker container!"
echo "📦 DevShell: $DEVSHELL_NAME"
echo "🔧 Flake: $FLAKE_PATH"
echo "💻 System: $SYSTEM"
echo ""
BASHRC_EOF

    # Copy bashrc to root for compatibility
    cp $WORKDIR/.bashrc /root/.bashrc || true
    
    # Set ownership
    $(if [[ -z "$USER" ]]; then
      echo "chown -R nixuser:nixuser $WORKDIR || true"
    fi)
    
    # Create additional volume directories
    $(for volume in "\${VOLUMES[@]}"; do
      echo "mkdir -p \$volume"
      echo "chmod 755 \$volume"
      if [[ -z "$USER" ]]; then
        echo "chown nixuser:nixuser \$volume || true"
      fi
    done)
  ''';
  
  $(if [[ "$LAYERED" == "true" ]]; then
    echo "maxLayers = 100;"
  fi)
}
EOF

log_verbose "Created Docker builder expression at $TEMP_DIR/docker-builder.nix"

# Build the Docker image
log_step "Building Docker image"
if [[ "$VERBOSE" == "true" ]]; then
    RESULT=$(nix-build "$TEMP_DIR/docker-builder.nix" --no-out-link --show-trace)
else
    log_info "Building... (this may take a while)"
    RESULT=$(nix-build "$TEMP_DIR/docker-builder.nix" --no-out-link 2>/dev/null)
fi

if [[ -n "$RESULT" ]]; then
    log_success "Docker image built successfully"
    log_verbose "Result path: $RESULT"
    
    # Load image into Docker or save to file
    if [[ "$LOAD_IMAGE" == "true" ]]; then
        log_step "Loading image into Docker"
        docker load < "$RESULT"
        log_success "Image loaded: $FULL_IMAGE_NAME:$TAG"
        
        # Show image info
        docker images "$FULL_IMAGE_NAME:$TAG"
        
    elif [[ -n "$SAVE_TO" ]]; then
        log_step "Saving image to file"
        cp "$RESULT" "$SAVE_TO"
        log_success "Image saved to: $SAVE_TO"
        
    else
        log_info "Image built but not loaded. Use --load to load into Docker or --output to save to file."
        log_verbose "Image path: $RESULT"
    fi
    
    # Push to registry if requested
    if [[ "$PUSH" == "true" ]]; then
        if [[ "$LOAD_IMAGE" != "true" ]]; then
            log_step "Loading image for push"
            docker load < "$RESULT"
        fi
        
        log_step "Pushing image to registry"
        docker push "$FULL_IMAGE_NAME:$TAG"
        log_success "Image pushed: $FULL_IMAGE_NAME:$TAG"
    fi
    
    # Show usage instructions
    log_step "Usage Instructions"
    log_info "Run the container with:"
    
    DOCKER_RUN_CMD="docker run -it --rm"
    
    # Add port mappings
    for port in "${PORTS[@]}"; do
        DOCKER_RUN_CMD+=" -p $port:$port"
    done
    
    # Add volume mappings
    DOCKER_RUN_CMD+=" -v \$(pwd):$WORKDIR"
    for volume in "${VOLUMES[@]}"; do
        DOCKER_RUN_CMD+=" -v $volume:$volume"
    done
    
    DOCKER_RUN_CMD+=" $FULL_IMAGE_NAME:$TAG"
    
    echo "  $DOCKER_RUN_CMD"
    
    if [[ ${#PORTS[@]} -gt 0 ]]; then
        log_info "Exposed ports: ${PORTS[*]}"
    fi
    
    if [[ ${#VOLUMES[@]} -gt 0 ]]; then
        log_info "Volumes: ${VOLUMES[*]}"
    fi
    
else
    log_error "Failed to build Docker image"
    exit 1
fi
#!/usr/bin/env bash

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counter
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_test() {
    echo -e "${YELLOW}[TEST]${NC} $1"
}

# Test functions
run_test() {
    local test_name="$1"
    local test_command="$2"
    
    log_test "Running: $test_name"
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if eval "$test_command"; then
        log_success "✓ $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        log_error "✗ $test_name"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# Test setup
setup_test_environment() {
    log_info "Setting up advanced test environment..."
    
    # Create temporary directory
    TEST_DIR=$(mktemp -d)
    export TEST_DIR
    
    log_info "Test directory: $TEST_DIR"
    
    # Create a multi-devshell test flake
    cat > "$TEST_DIR/flake.nix" << 'EOF'
{
  description = "Advanced test flake for flake2docker";
  
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };
  
  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in {
        devShells = {
          default = pkgs.mkShell {
            buildInputs = with pkgs; [
              hello
              jq
              curl
            ];
            shellHook = ''
              echo "Default test environment loaded!"
            '';
          };
          
          web = pkgs.mkShell {
            buildInputs = with pkgs; [
              nodejs_20
              python3
            ];
            shellHook = ''
              echo "Web development environment loaded!"
            '';
          };
          
          minimal = pkgs.mkShell {
            buildInputs = with pkgs; [
              coreutils
            ];
            shellHook = ''
              echo "Minimal test environment loaded!"
            '';
          };
        };
      });
}
EOF
    
    cd "$TEST_DIR"
    log_success "Advanced test environment set up"
}

# Cleanup
cleanup_test_environment() {
    log_info "Cleaning up advanced test environment..."
    
    # Remove test images
    docker rmi test-default:latest 2>/dev/null || true
    docker rmi test-web:latest 2>/dev/null || true
    docker rmi test-minimal:latest 2>/dev/null || true
    docker rmi layered-test:latest 2>/dev/null || true
    
    # Clean up temporary directory
    rm -rf "$TEST_DIR"
    
    log_success "Advanced test environment cleaned up"
}

# Test cases
test_multi_devshell_default() {
    nix run ..#flake2docker-advanced -- -f . -d default -n test-default -t latest -o test-default.tar
    test -f test-default.tar
}

test_multi_devshell_web() {
    nix run ..#flake2docker-advanced -- -f . -d web -n test-web -t latest -o test-web.tar
    test -f test-web.tar
}

test_multi_devshell_minimal() {
    nix run ..#flake2docker-advanced -- -f . -d minimal -n test-minimal -t latest -o test-minimal.tar
    test -f test-minimal.tar
}

test_layered_build() {
    nix run ..#flake2docker-advanced -- -f . --layered -n layered-test -t latest -o layered-test.tar
    test -f layered-test.tar
}

test_custom_config() {
    nix run ..#flake2docker-advanced -- \
        -f . \
        -n custom-test \
        -t latest \
        --port 8080 \
        --env NODE_ENV=test \
        --env DEBUG=true \
        --volume /tmp/data \
        --label version=1.0.0 \
        --workdir /app \
        -o custom-test.tar
    test -f custom-test.tar
}

test_docker_load_multi() {
    if command -v docker &> /dev/null && docker info &> /dev/null; then
        nix run ..#flake2docker-advanced -- -f . -d web -n test-web -t latest --load
        docker images | grep test-web
    else
        log_info "Docker not available, skipping Docker load test"
        return 0
    fi
}

test_example_flakes() {
    # Test basic-devenv example
    nix run ..#flake2docker -- -f ../examples/basic-devenv.nix -n basic-test -t latest -o basic-test.tar
    test -f basic-test.tar
    
    # Test web-app example
    nix run ..#flake2docker-advanced -- -f ../examples/web-app.nix -n webapp-test -t latest -o webapp-test.tar
    test -f webapp-test.tar
    
    # Test multi-devshells frontend
    nix run ..#flake2docker-advanced -- -f ../examples/multi-devshells.nix -d frontend -n frontend-test -t latest -o frontend-test.tar
    test -f frontend-test.tar
}

test_error_handling() {
    # Test non-existent flake
    if nix run ..#flake2docker -- -f /nonexistent/path --help 2>/dev/null; then
        return 1  # Should fail
    fi
    
    # Test non-existent devshell
    if nix run ..#flake2docker-advanced -- -f . -d nonexistent -n test -t latest -o test.tar 2>/dev/null; then
        return 1  # Should fail
    fi
    
    return 0
}

# Main test runner
main() {
    log_info "🧪 Running flake2docker advanced tests"
    log_info "======================================"
    
    # Set up test environment
    setup_test_environment
    
    # Set trap for cleanup
    trap cleanup_test_environment EXIT
    
    # Run tests
    run_test "Multi-devshell default" test_multi_devshell_default
    run_test "Multi-devshell web" test_multi_devshell_web
    run_test "Multi-devshell minimal" test_multi_devshell_minimal
    run_test "Layered build" test_layered_build
    run_test "Custom configuration" test_custom_config
    run_test "Docker load multi" test_docker_load_multi
    run_test "Example flakes" test_example_flakes
    run_test "Error handling" test_error_handling
    
    # Summary
    log_info "Advanced Test Results:"
    log_info "  Tests run: $TESTS_RUN"
    log_success "  Passed: $TESTS_PASSED"
    
    if [[ $TESTS_FAILED -gt 0 ]]; then
        log_error "  Failed: $TESTS_FAILED"
        exit 1
    else
        log_success "All advanced tests passed! 🎉"
        exit 0
    fi
}

# Run main function
main "$@"
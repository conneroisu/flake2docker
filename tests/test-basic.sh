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
    log_info "Setting up test environment..."
    
    # Create temporary directory
    TEST_DIR=$(mktemp -d)
    export TEST_DIR
    
    log_info "Test directory: $TEST_DIR"
    
    # Create a simple test flake
    cat > "$TEST_DIR/flake.nix" << 'EOF'
{
  description = "Test flake for flake2docker";
  
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };
  
  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system: {
      devShells.default = nixpkgs.legacyPackages.${system}.mkShell {
        buildInputs = with nixpkgs.legacyPackages.${system}; [
          hello
          jq
        ];
        shellHook = ''
          echo "Test environment loaded!"
        '';
      };
    });
}
EOF
    
    cd "$TEST_DIR"
    log_success "Test environment set up"
}

# Cleanup
cleanup_test_environment() {
    log_info "Cleaning up test environment..."
    
    # Remove test images
    docker rmi flake2docker-test:latest 2>/dev/null || true
    docker rmi test-image:latest 2>/dev/null || true
    
    # Clean up temporary directory
    rm -rf "$TEST_DIR"
    
    log_success "Test environment cleaned up"
}

# Test cases
test_flake_validity() {
    nix flake check
}

test_basic_help() {
    nix run ..#flake2docker -- --help > /dev/null
}

test_advanced_help() {
    nix run ..#flake2docker-advanced -- --help > /dev/null
}

test_basic_build() {
    nix run ..#flake2docker -- -f . -n flake2docker-test -t latest -o test-image.tar
    test -f test-image.tar
}

test_advanced_build() {
    nix run ..#flake2docker-advanced -- -f . -n test-image -t latest -o test-image-advanced.tar
    test -f test-image-advanced.tar
}

test_docker_load() {
    if command -v docker &> /dev/null && docker info &> /dev/null; then
        nix run ..#flake2docker -- -f . -n flake2docker-test -t latest --load
        docker images | grep flake2docker-test
    else
        log_info "Docker not available, skipping Docker load test"
        return 0
    fi
}

test_shell_scripts() {
    shellcheck ../src/flake2docker.sh
    shellcheck ../src/flake2docker-advanced.sh
}

# Main test runner
main() {
    log_info "🧪 Running flake2docker basic tests"
    log_info "=================================="
    
    # Set up test environment
    setup_test_environment
    
    # Set trap for cleanup
    trap cleanup_test_environment EXIT
    
    # Run tests
    run_test "Flake validity" test_flake_validity
    run_test "Basic CLI help" test_basic_help
    run_test "Advanced CLI help" test_advanced_help
    run_test "Basic build to file" test_basic_build
    run_test "Advanced build to file" test_advanced_build
    run_test "Docker load test" test_docker_load
    run_test "Shell script validation" test_shell_scripts
    
    # Summary
    log_info "Test Results:"
    log_info "  Tests run: $TESTS_RUN"
    log_success "  Passed: $TESTS_PASSED"
    
    if [[ $TESTS_FAILED -gt 0 ]]; then
        log_error "  Failed: $TESTS_FAILED"
        exit 1
    else
        log_success "All tests passed! 🎉"
        exit 0
    fi
}

# Run main function
main "$@"
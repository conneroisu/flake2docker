#!/usr/bin/env bash

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Test results
TOTAL_TESTS=0
TOTAL_PASSED=0
TOTAL_FAILED=0

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

log_header() {
    echo -e "${PURPLE}[HEADER]${NC} $1"
}

# Test runner function
run_test_suite() {
    local test_name="$1"
    local test_script="$2"
    
    log_header "🧪 Running $test_name"
    echo "========================================"
    
    if bash "$test_script"; then
        log_success "✅ $test_name completed successfully"
        return 0
    else
        log_error "❌ $test_name failed"
        return 1
    fi
}

# Pre-test checks
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if nix is available
    if ! command -v nix &> /dev/null; then
        log_error "Nix is not installed or not in PATH"
        exit 1
    fi
    
    # Check if we can run flake commands
    if ! nix flake --help &> /dev/null; then
        log_error "Nix flakes not available"
        exit 1
    fi
    
    # Check if shellcheck is available
    if ! command -v shellcheck &> /dev/null; then
        log_info "Installing shellcheck..."
        nix profile install nixpkgs#shellcheck || true
    fi
    
    # Check if docker is available and running
    if command -v docker &> /dev/null && docker info &> /dev/null; then
        log_info "Docker is available and running"
    else
        log_info "Docker not available - some tests will be skipped"
    fi
    
    log_success "Prerequisites check completed"
}

# Main test execution
main() {
    log_header "🚀 flake2docker Test Suite"
    log_header "=========================="
    
    # Get script directory
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    # Check prerequisites
    check_prerequisites
    
    # Track start time
    START_TIME=$(date +%s)
    
    # Run test suites
    FAILED_SUITES=()
    
    # Basic tests
    if run_test_suite "Basic Tests" "$SCRIPT_DIR/test-basic.sh"; then
        TOTAL_PASSED=$((TOTAL_PASSED + 1))
    else
        TOTAL_FAILED=$((TOTAL_FAILED + 1))
        FAILED_SUITES+=("Basic Tests")
    fi
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    echo ""
    
    # Advanced tests
    if run_test_suite "Advanced Tests" "$SCRIPT_DIR/test-advanced.sh"; then
        TOTAL_PASSED=$((TOTAL_PASSED + 1))
    else
        TOTAL_FAILED=$((TOTAL_FAILED + 1))
        FAILED_SUITES+=("Advanced Tests")
    fi
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    # Calculate end time
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    
    # Final summary
    echo ""
    log_header "📊 Test Suite Summary"
    log_header "===================="
    log_info "Total test suites: $TOTAL_TESTS"
    log_success "Passed: $TOTAL_PASSED"
    
    if [[ $TOTAL_FAILED -gt 0 ]]; then
        log_error "Failed: $TOTAL_FAILED"
        log_error "Failed suites: ${FAILED_SUITES[*]}"
        echo ""
        log_error "❌ Some tests failed. Please check the output above."
        exit 1
    else
        log_success "All test suites passed! 🎉"
    fi
    
    log_info "Total execution time: ${DURATION}s"
    
    # Additional information
    echo ""
    log_header "🎯 Next Steps"
    log_header "============"
    log_info "You can now:"
    log_info "  • Build Docker images: make docker-build"
    log_info "  • Run examples: make examples"
    log_info "  • Install the CLI: make install"
    log_info "  • Run demo: make demo"
    
    exit 0
}

# Run with error handling
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
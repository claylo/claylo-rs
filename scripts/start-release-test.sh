#!/bin/bash
# Start local crates.io registry and expose via ngrok for release testing.
#
# Prerequisites:
#   - Docker running
#   - ngrok installed and authenticated (ngrok config add-authtoken <token>)
#   - gh CLI authenticated
#   - ~/source/claylo/crates-io-local cloned
#
# Usage:
#   ./scripts/start-release-test.sh
#   ./scripts/start-release-test.sh --stop

set -euo pipefail

CRATES_IO_LOCAL="${CRATES_IO_LOCAL:-$HOME/source/claylo/crates-io-local}"
TEST_REPO="${TEST_REPO:-claylo/claylo-rs-release-test}"
REGISTRY_PORT="${REGISTRY_PORT:-8888}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

info() { echo -e "${GREEN}==>${NC} $1"; }
warn() { echo -e "${YELLOW}==>${NC} $1"; }
error() { echo -e "${RED}==>${NC} $1" >&2; }

# Stop everything
stop() {
    info "Stopping release test environment..."

    # Stop ngrok
    if pgrep -x ngrok >/dev/null; then
        pkill -x ngrok
        info "Stopped ngrok"
    fi

    # Stop crates-io-local
    if [ -d "$CRATES_IO_LOCAL" ]; then
        (cd "$CRATES_IO_LOCAL" && docker compose down)
        info "Stopped crates-io-local"
    fi

    info "Done"
    exit 0
}

# Handle --stop flag
if [[ "${1:-}" == "--stop" ]]; then
    stop
fi

# Check prerequisites
check_prereqs() {
    local missing=()

    command -v docker >/dev/null || missing+=("docker")
    command -v ngrok >/dev/null || missing+=("ngrok")
    command -v gh >/dev/null || missing+=("gh")
    command -v jq >/dev/null || missing+=("jq")

    if [ ${#missing[@]} -ne 0 ]; then
        error "Missing required tools: ${missing[*]}"
        exit 1
    fi

    if [ ! -d "$CRATES_IO_LOCAL" ]; then
        error "crates-io-local not found at $CRATES_IO_LOCAL"
        echo "  Clone it: gh repo clone claylo/crates-io-local $CRATES_IO_LOCAL"
        exit 1
    fi

    if ! docker info >/dev/null 2>&1; then
        error "Docker is not running"
        exit 1
    fi
}

# Start crates-io-local
start_registry() {
    info "Starting crates-io-local..."
    (cd "$CRATES_IO_LOCAL" && docker compose up -d)

    info "Waiting for registry to be ready..."
    local attempts=0
    local max_attempts=30
    until curl -s "http://localhost:${REGISTRY_PORT}/api/v1/summary" >/dev/null 2>&1; do
        attempts=$((attempts + 1))
        if [ $attempts -ge $max_attempts ]; then
            error "Registry failed to start after ${max_attempts} attempts"
            exit 1
        fi
        sleep 2
    done
    info "Registry ready at http://localhost:${REGISTRY_PORT}"
}

# Start ngrok
start_ngrok() {
    # Kill existing ngrok if running
    if pgrep -x ngrok >/dev/null; then
        warn "ngrok already running, restarting..."
        pkill -x ngrok
        sleep 1
    fi

    info "Starting ngrok tunnel..."
    ngrok http "$REGISTRY_PORT" >/dev/null 2>&1 &

    # Wait for ngrok to be ready
    local attempts=0
    local max_attempts=10
    until curl -s http://localhost:4040/api/tunnels >/dev/null 2>&1; do
        attempts=$((attempts + 1))
        if [ $attempts -ge $max_attempts ]; then
            error "ngrok failed to start"
            exit 1
        fi
        sleep 1
    done
}

# Get ngrok URL and update secrets
update_secrets() {
    local ngrok_url
    ngrok_url=$(curl -s http://localhost:4040/api/tunnels | jq -r '.tunnels[] | select(.proto == "https") | .public_url')

    if [ -z "$ngrok_url" ] || [ "$ngrok_url" == "null" ]; then
        error "Failed to get ngrok URL"
        exit 1
    fi

    info "ngrok URL: $ngrok_url"

    local registry_url="sparse+${ngrok_url}/api/v1/crates/"

    info "Updating secrets in $TEST_REPO..."
    gh secret set LOCAL_REGISTRY_URL --repo "$TEST_REPO" --body "$registry_url"
    gh secret set LOCAL_REGISTRY_TOKEN --repo "$TEST_REPO" --body "test-token"

    info "Secrets updated"
}

# Print status
print_status() {
    local ngrok_url
    ngrok_url=$(curl -s http://localhost:4040/api/tunnels | jq -r '.tunnels[] | select(.proto == "https") | .public_url')

    echo ""
    echo "========================================"
    echo " Release Test Environment Ready"
    echo "========================================"
    echo ""
    echo " Local registry:  http://localhost:${REGISTRY_PORT}"
    echo " Public URL:      ${ngrok_url}"
    echo " Sparse index:    sparse+${ngrok_url}/api/v1/crates/"
    echo " Test repo:       https://github.com/${TEST_REPO}"
    echo ""
    echo " ngrok dashboard: http://localhost:4040"
    echo ""
    echo " To test a release:"
    echo "   1. Generate project: copier copy --trust --defaults . /tmp/test-release"
    echo "   2. Push to test repo"
    echo "   3. Tag and push: git tag v0.1.0 && git push origin v0.1.0"
    echo ""
    echo " To stop: $0 --stop"
    echo ""
}

# Main
main() {
    check_prereqs
    start_registry
    start_ngrok
    update_secrets
    print_status
}

main

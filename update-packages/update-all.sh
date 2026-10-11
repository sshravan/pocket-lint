#!/usr/bin/env bash
# Define ANSI Color Codes
CYAN='\033[1;36m'
GREEN='\033[1;32m'
BLUE='\033[1;34m'
PURPLE='\033[1;35m'
RESET='\033[0m'

print_step() {
    echo -e "\n${CYAN}================================================================${RESET}"
    echo -e " $1"
    echo -e "${CYAN}================================================================${RESET}\n"
}

ZSH="${ZSH:-$HOME/.oh-my-zsh}"
if [ -f "$ZSH/tools/upgrade.sh" ]; then
    print_step "🐚 Updating Oh My Zsh..."
    ZSH="$ZSH" zsh "$ZSH/tools/upgrade.sh"
fi

OMB="${OMB:-$HOME/.oh-my-bash}"
if [ -d "$OMB/.git" ]; then
    print_step "🐚 Updating Oh My Bash..."
    git -C "$OMB" pull --ff-only
fi

if command -v claude >/dev/null 2>&1; then
    print_step "🤖 Updating Claude CLI..."
    claude update
fi

if command -v agy >/dev/null 2>&1; then
    print_step "⚡ Updating Agy..."
    agy update
fi

if command -v uv >/dev/null 2>&1; then
    print_step "🚀 Updating UV Package Manager..."
    uv self update
fi

if command -v rustup >/dev/null 2>&1; then
    print_step "🦀 Updating Rust Toolchain..."
    rustup update
fi

if command -v flatpak >/dev/null 2>&1; then
    print_step "📦 Updating Flatpak Applications..."
    flatpak update -y
fi

if command -v brew >/dev/null 2>&1; then
    print_step "🍺 Updating Homebrew Packages..."
    brew update && brew upgrade --greedy
fi

if command -v code >/dev/null 2>&1; then
    print_step "💻 Updating VS Code Extensions..."
    code --update-extensions
fi

if command -v uv >/dev/null 2>&1; then
    print_step "🐍 Upgrading Global Python Packages (UV)..."
    uv pip list --format=freeze | cut -d= -f1 | xargs uv pip install -U

    print_step "🧹 Pruning UV Cache..."
    uv cache prune
fi

OLLAMA_BIN="$(command -v ollama 2>/dev/null || true)"
[ -z "$OLLAMA_BIN" ] && [ -x "$HOME/.local/bin/ollama" ] && OLLAMA_BIN="$HOME/.local/bin/ollama"

if [ -n "$OLLAMA_BIN" ]; then
    OLLAMA_BIN="$(readlink -f "$OLLAMA_BIN")"
    OLLAMA_PREFIX="$(dirname "$(dirname "$OLLAMA_BIN")")"

    case "$OLLAMA_PREFIX" in
        "$HOME"/*)
            print_step "🦙 Checking Ollama version..."

            # Get installed version
            CURRENT_VERSION="$("$OLLAMA_BIN" --version 2>&1 |
                grep -oE '[0-9]+\.[0-9]+\.[0-9]+' |
                head -n1)"

            # Get latest stable release (exclude prereleases)
            LATEST_VERSION="$(
                curl -fsSL https://api.github.com/repos/ollama/ollama/releases/latest |
                jq -r '.tag_name // empty' |
                sed 's/^v//'
            )"

            if [ -z "$CURRENT_VERSION" ] || [ -z "$LATEST_VERSION" ]; then
                echo "⚠️ Could not determine Ollama versions; skipping update."
            elif [ "$CURRENT_VERSION" = "$LATEST_VERSION" ]; then
                echo "✅ Ollama is already up to date ($CURRENT_VERSION)."
            else
                # Compare versions using sort -V
                NEWER_VERSION="$(printf '%s\n%s\n' \
                    "$CURRENT_VERSION" "$LATEST_VERSION" |
                    sort -V | tail -n1)"

                if [ "$NEWER_VERSION" != "$LATEST_VERSION" ]; then
                    echo "✅ Installed Ollama ($CURRENT_VERSION) is newer than or equal to latest ($LATEST_VERSION)."
                else
                    print_step "🦙 Updating Ollama: $CURRENT_VERSION → $LATEST_VERSION"

                    case "$(uname -m)" in
                        aarch64|arm64) OLLAMA_ARCH=arm64 ;;
                        x86_64|amd64) OLLAMA_ARCH=amd64 ;;
                        *)
                            echo "Unsupported architecture: $(uname -m)" >&2
                            exit 1
                            ;;
                    esac

                    if ! command -v zstd >/dev/null 2>&1; then
                        echo "Error: zstd is required to update Ollama." >&2
                        exit 1
                    fi

                    set -o pipefail

                    if curl -fsSL \
                        "https://ollama.com/download/ollama-linux-${OLLAMA_ARCH}.tar.zst" |
                        zstd -d |
                        tar -x -C "$OLLAMA_PREFIX"; then
                        echo "✅ Ollama update completed."
                    else
                        echo "❌ Ollama update failed." >&2
                        exit 1
                    fi
                fi
            fi
            ;;
        *)
            echo "ℹ️ Ollama is not installed under HOME; skipping local update."
            ;;
    esac
fi

if command -v tlmgr >/dev/null 2>&1; then
    print_step "📜 Updating TeX Live Packages (TLMgr)..."
    tlmgr update --self --all
fi

print_step "🔐 Updating System Packages..."

# Invalidate any previously cached sudo credentials
sudo -k

# Authenticate once, then run all package updates
if sudo -v; then
    if command -v snap >/dev/null 2>&1; then
        print_step "🧩 Checking for Snap updates..."

        pending_snaps=$(snap refresh --list 2>/dev/null | awk 'NR>1 {print $1}')

        if [ -n "$pending_snaps" ]; then
            for snap_name in $pending_snaps; do
                if pgrep -f "/snap/$snap_name/" >/dev/null 2>&1; then
                    echo "⚠️ Snap '$snap_name' has an update waiting, but is currently open and running."
                    ps -ef | grep "/snap/$snap_name/" | grep -v grep |
                        awk '{print "   PID: "$2" | "$8}'
                fi
            done
        fi

        print_step "🧩 Refreshing Snap Packages..."
        sudo snap refresh
    fi

    if command -v apt-get >/dev/null 2>&1; then
        print_step "📦 Updating System Packages (APT)..."
        sudo apt-get update &&
            sudo apt-get dist-upgrade -y &&
            sudo apt-get autoremove
    fi

    # Clear cached credentials after package maintenance
    sudo -k
else
    echo "❌ Sudo authentication failed; skipping package updates." >&2
fi

echo -e "\n${GREEN}✨ All updates finished successfully! ✨${RESET}\n"

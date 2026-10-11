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
    ZSH="$ZSH" sh "$ZSH/tools/upgrade.sh"
fi

if command -v agy >/dev/null 2>&1; then
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

OLLAMA_BIN="$(command -v ollama 2>/dev/null)"
[ -z "$OLLAMA_BIN" ] && [ -x "$HOME/.local/bin/ollama" ] && OLLAMA_BIN="$HOME/.local/bin/ollama"
if [ -n "$OLLAMA_BIN" ]; then
    OLLAMA_BIN="$(readlink -f "$OLLAMA_BIN")"
    OLLAMA_PREFIX="$(dirname "$(dirname "$OLLAMA_BIN")")"
    case "$OLLAMA_PREFIX" in
        "$HOME"/*)
            print_step "🦙 Updating Ollama (local install in $OLLAMA_PREFIX)..."
            case "$(uname -m)" in
                aarch64|arm64) OLLAMA_ARCH=arm64 ;;
                *) OLLAMA_ARCH=amd64 ;;
            esac
            curl -fsSL "https://ollama.com/download/ollama-linux-${OLLAMA_ARCH}.tar.zst" | zstd -d | tar -x -C "$OLLAMA_PREFIX"
            ;;
    esac
fi

if command -v tlmgr >/dev/null 2>&1; then
    print_step "📜 Updating TeX Live Packages (TLMgr)..."
    tlmgr update --self --all
fi

if command -v snap >/dev/null 2>&1; then
    print_step "🧩 Refreshing Snap Packages..."
    sudo snap refresh
    # sudo -k snap refresh
fi

if command -v apt-get >/dev/null 2>&1; then
    print_step "📦 Updating System Packages (APT)..."
    sudo apt-get update; sudo apt-get dist-upgrade -y; sudo apt-get autoremove
    # sudo -k apt-get update; sudo apt-get dist-upgrade -y; sudo apt-get autoremove
fi

echo -e "\n${GREEN}✨ All updates finished successfully! ✨${RESET}\n"

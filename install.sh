#!/usr/bin/env bash
set -euo pipefail

# Dotfiles directory (where this script lives)
DOTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Subdirectories to stow (each maps to entries in $HOME)
STOW_TARGETS=(
    aerospace
    emacs
    espanso
    git
    hypr
    i3
    kitty
    nvim
    sioyek
    starship
    tmux-sessionizer
    tmux
    vim
    waybar
    zsh
)

info() { printf "\033[1;34m==>\033[0m %s\n" "$*"; }
err()  { printf "\033[1;31mError:\033[0m %s\n" "$*" >&2; }

install_stow() {
    if command -v stow >/dev/null 2>&1; then
        info "GNU Stow already installed: $(stow --version 2>&1 | head -n1)"
        return 0
    fi

    info "Detecting system..."
    local os
    os="$(uname -s)"

    case "$os" in
        Linux)
            if [ -f /etc/os-release ]; then
                # shellcheck disable=SC1091
                . /etc/os-release
                case "${ID:-}:${ID_LIKE:-}" in
                    ubuntu:*|*ubuntu*|debian:*|*debian*)
                        info "Installing stow via apt..."
                        sudo apt update && sudo apt install -y stow
                        ;;
                    arch:*)
                        info "Installing stow via pacman..."
                        sudo pacman -Sy --noconfirm stow
                        ;;
                    *)
                        err "Unsupported Linux distribution: ${ID:-unknown}"
                        err "Please install GNU Stow manually and re-run."
                        exit 1
                        ;;
                esac
            else
                err "Cannot detect Linux distribution (no /etc/os-release)."
                err "Please install GNU Stow manually and re-run."
                exit 1
            fi
            ;;
        Darwin)
            if ! command -v brew >/dev/null 2>&1; then
                err "Homebrew is required on macOS but was not found."
                err " Install it from https://brew.sh and re-run."
                exit 1
            fi
            info "Installing stow via Homebrew..."
            brew install stow
            ;;
        *)
            err "Unsupported OS: $os"
            exit 1
            ;;
    esac

    if ! command -v stow >/dev/null 2>&1; then
        err "GNU Stow installation failed."
        exit 1
    fi
}

stow_all() {
    info "Stowing configs from $DOTS_DIR into $HOME..."
    cd "$DOTS_DIR"

    # Adopt pre-existing files (replace them with symlinks) so stow doesn't fail
    # on conflicts; backups are not made since these are dotfiles under version control.
    for pkg in "${STOW_TARGETS[@]}"; do
        if [ ! -d "$pkg" ]; then
            info "Skipping missing package: $pkg"
            continue
        fi
        info "Stowing $pkg..."
        stow --target="$HOME" "$pkg" || {
            err "Failed to stow $pkg (conflict?). Inspect and re-run."
            stow --target="$HOME" --verbose "$pkg" || true
        }
    done
}

main() {
    info "Dotfiles installer"
    install_stow
    stow_all
    info "Done. Restart your shell for zsh changes to take effect."
}

main "$@"

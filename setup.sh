#!/usr/bin/env bash
# Set up the shared command-line configuration on macOS or Linux.
#
# Usage:
#   ./setup.sh [--skip-packages] [--github] [--ssh-key] [--dry-run]
#
# The script only creates symlinks and updates this user's Git configuration.
# Existing dotfiles are moved to a dated backup before a link is created.

set -euo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SKIP_PACKAGES=false
LINK_GITHUB=false
CREATE_SSH_KEY=false
DRY_RUN=false
DONE=()
SKIPPED=()
PENDING=()

add_status() {
  local category="$1"
  local message="$2"
  case "$category" in
    done) DONE+=("$message") ;;
    skipped) SKIPPED+=("$message") ;;
    pending) PENDING+=("$message") ;;
  esac
}

print_summary() {
  local item
  printf '\nSetup summary\nDone:\n'
  if ((${#DONE[@]})); then
    for item in "${DONE[@]}"; do printf '  - %s\n' "$item"; done
  else
    printf '  - Nothing was changed.\n'
  fi
  printf 'Skipped:\n'
  if ((${#SKIPPED[@]})); then
    for item in "${SKIPPED[@]}"; do printf '  - %s\n' "$item"; done
  else
    printf '  - Nothing.\n'
  fi
  printf 'Still to do:\n'
  if ((${#PENDING[@]})); then
    for item in "${PENDING[@]}"; do printf '  - %s\n' "$item"; done
  else
    printf '  - Nothing.\n'
  fi
}

usage() {
  sed -n '1,12p' "$0"
}

run() {
  if "$DRY_RUN"; then
    printf '+'
    printf ' %q' "$@"
    printf '\n'
  else
    "$@"
  fi
}

while (($#)); do
  case "$1" in
    --skip-packages) SKIP_PACKAGES=true ;;
    --github) LINK_GITHUB=true ;;
    --ssh-key) CREATE_SSH_KEY=true; LINK_GITHUB=true ;;
    --dry-run) DRY_RUN=true ;;
    --help|-h) usage; exit 0 ;;
    *) printf 'Unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

install_packages() {
  local manager
  local -a packages

  if command -v brew >/dev/null; then
    manager=brew
    packages=(zsh git fzf ripgrep fd bat eza zoxide micro gh git-delta direnv uv)
  elif command -v apt-get >/dev/null; then
    manager=apt
    packages=(zsh git fzf ripgrep fd-find bat eza zoxide micro gh git-delta direnv uv)
  elif command -v dnf >/dev/null; then
    manager=dnf
    packages=(zsh git fzf ripgrep fd-find bat eza zoxide micro gh git-delta direnv uv)
  elif command -v pacman >/dev/null; then
    manager=pacman
    packages=(zsh git fzf ripgrep fd bat eza zoxide micro github-cli git-delta direnv uv)
  else
    printf 'No supported package manager found. Install the tools listed in README.md manually.\n' >&2
    add_status skipped 'Package installation: no supported package manager'
    return
  fi

  # Packages are independent: an unavailable optional package must not prevent
  # installation of the usable base configuration or the remaining tools.
  printf 'Installing optional productivity tools with %s...\n' "$manager"
  local package
  for package in "${packages[@]}"; do
    if case "$manager" in
      brew) run brew install "$package" ;;
      apt) run sudo apt-get install -y "$package" ;;
      dnf) run sudo dnf install -y "$package" ;;
      pacman) run sudo pacman -S --needed --noconfirm "$package" ;;
    esac
    then
      if "$DRY_RUN"; then
        add_status pending "Would install: $package"
      else
        add_status done "Installed or already present: $package"
      fi
    else
      printf 'Skipped unavailable package: %s\n' "$package" >&2
      add_status skipped "Package unavailable or failed: $package"
    fi
  done
}

link_file() {
  local source_file="$1"
  local target_file="$2"
  local backup_dir="${HOME}/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"

  if [[ -L "$target_file" && "$(readlink "$target_file")" == "$source_file" ]]; then
    printf 'Already linked: %s\n' "$target_file"
    add_status done "Already linked: $target_file"
    return
  fi
  if [[ -e "$target_file" || -L "$target_file" ]]; then
    run mkdir -p "$backup_dir"
    run mv "$target_file" "$backup_dir/"
    printf 'Backed up %s to %s\n' "$target_file" "$backup_dir"
  fi
  run ln -s "$source_file" "$target_file"
  printf 'Linked %s\n' "$target_file"
  if "$DRY_RUN"; then
    add_status pending "Would link: $target_file"
  else
    add_status done "Linked: $target_file"
  fi
}

configure_git() {
  run git config --global include.path "$REPO_DIR/.gitconfig"
  if "$DRY_RUN"; then
    add_status pending 'Would include shared Git configuration'
    add_status pending 'Git identity not checked during dry run'
    return
  fi
  add_status done 'Included shared Git configuration'
  if [[ -z "$(git config --global --get user.name || true)" && -t 0 ]]; then
    read -r -p "Git display name (leave blank to configure later): " git_name
    if [[ -n "$git_name" ]]; then
      run git config --global user.name "$git_name"
    fi
  fi
  if [[ -z "$(git config --global --get user.email || true)" && -t 0 ]]; then
    read -r -p "Git email (leave blank to configure later): " git_email
    if [[ -n "$git_email" ]]; then
      run git config --global user.email "$git_email"
    fi
  fi
  if [[ -n "$(git config --global --get user.name || true)" ]]; then
    add_status done 'Git display name is configured'
  else
    add_status pending 'Set Git display name: git config --global user.name "Your Name"'
  fi
  if [[ -n "$(git config --global --get user.email || true)" ]]; then
    add_status done 'Git email is configured'
  else
    add_status pending 'Set Git email: git config --global user.email "you@example.com"'
  fi
}

link_github() {
  command -v gh >/dev/null || {
    printf 'GitHub CLI is not installed; rerun after installing gh.\n' >&2
    add_status pending 'Install GitHub CLI, then rerun with --github'
    return
  }
  if "$DRY_RUN"; then
    add_status pending 'Would authenticate GitHub CLI and configure Git HTTPS access'
    "$CREATE_SSH_KEY" && add_status pending 'Would create/upload an SSH key'
    return
  fi
  gh auth status >/dev/null 2>&1 || run gh auth login --git-protocol https --web
  run gh auth setup-git

  if "$CREATE_SSH_KEY"; then
    local key_file="${HOME}/.ssh/id_ed25519"
    if [[ ! -e "$key_file" ]]; then
      run ssh-keygen -t ed25519 -f "$key_file" -C "$(git config --global --get user.email || true)"
    fi
    run gh ssh-key add "${key_file}.pub" --title "$(hostname)-$(date +%F)"
    add_status done 'Uploaded SSH public key to GitHub'
  fi
  run gh auth status
  add_status done 'Authenticated GitHub CLI and configured Git HTTPS access'
}

if ! "$SKIP_PACKAGES"; then
  install_packages
else
  add_status skipped 'Package installation requested to be skipped'
fi

link_file "$REPO_DIR/.zsh" "$HOME/.zsh"
link_file "$REPO_DIR/.zshrc" "$HOME/.zshrc"
link_file "$REPO_DIR/.zprofile" "$HOME/.zprofile"
configure_git
"$LINK_GITHUB" && link_github
if ! "$LINK_GITHUB"; then
  add_status pending 'Connect GitHub: rerun with --skip-packages --github or --ssh-key'
fi

print_summary
printf '\nRestart Zsh to load the configuration.\n'

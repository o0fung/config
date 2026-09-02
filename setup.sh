#!/usr/bin/env bash
# Set up the shared command-line configuration on macOS or Linux.
#
# Usage:
#   ./setup.sh [--skip-packages] [--system-upgrade] [--github] [--ssh-key] [--dry-run]
#
# The script only creates symlinks and updates this user's Git configuration.
# Existing dotfiles are moved to a dated backup before a link is created.

set -euo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
export PATH="$HOME/.local/bin:$PATH"
SKIP_PACKAGES=false
LINK_GITHUB=false
CREATE_SSH_KEY=false
DRY_RUN=false
SYSTEM_UPGRADE=false
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
    --system-upgrade) SYSTEM_UPGRADE=true ;;
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
  if [[ "$manager" == apt ]]; then
    # Refresh package metadata before installing. A full system upgrade is
    # deliberately opt-in because it can update unrelated libraries or the
    # kernel and may require a restart on an otherwise usable computer.
    if run sudo apt-get update; then
      if "$DRY_RUN"; then
        add_status pending 'Would refresh apt package metadata'
      else
        add_status done 'Refreshed apt package metadata'
      fi
    else
      printf 'Could not refresh apt package metadata; continuing with the existing cache.\n' >&2
      add_status skipped 'apt package metadata refresh failed'
    fi
    if "$SYSTEM_UPGRADE"; then
      if run sudo apt-get upgrade -y; then
        if "$DRY_RUN"; then
          add_status pending 'Would upgrade installed apt packages'
        else
          add_status done 'Upgraded installed apt packages'
        fi
      else
        printf 'System upgrade failed; continuing with tool installation.\n' >&2
        add_status skipped 'apt system upgrade failed'
      fi
    fi
  elif "$SYSTEM_UPGRADE"; then
    printf '--system-upgrade only applies to apt-based Linux systems.\n' >&2
    add_status skipped 'System upgrade: unsupported package manager'
  fi
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

setup_python() {
  local python_env_dir="$HOME/.venv/python-3.13"

  # uv supplies the same CPython 3.13 release on every supported platform,
  # avoiding distribution-specific package availability and system-Python
  # restrictions. The fallback is only used when the package manager lacked uv.
  if ! command -v uv >/dev/null 2>&1; then
    if command -v curl >/dev/null 2>&1; then
      if run bash -c 'curl -LsSf https://astral.sh/uv/install.sh | sh'; then
        hash -r
        if "$DRY_RUN"; then
          add_status pending 'Would install uv from Astral'
        else
          add_status done 'Installed uv from Astral'
        fi
      else
        add_status skipped 'Could not install uv'
      fi
    else
      printf 'uv and curl are unavailable; Python 3.13 setup was skipped.\n' >&2
      add_status pending 'Install uv, then rerun setup to configure Python 3.13'
      return
    fi
  fi

  if [[ "$DRY_RUN" != true ]] && ! command -v uv >/dev/null 2>&1; then
    add_status pending 'Install uv, then rerun setup to configure Python 3.13'
    return
  fi
  if run uv python install --default 3.13; then
    if "$DRY_RUN"; then
      add_status pending 'Would install default Python 3.13 with uv'
    else
      add_status done 'Installed default Python 3.13 with uv'
    fi
  else
    add_status skipped 'Could not install Python 3.13'
    return
  fi
  if run uv venv "$python_env_dir" --python 3.13 --seed; then
    if "$DRY_RUN"; then
      add_status pending "Would create shared Python environment: $python_env_dir"
    else
      add_status done "Created or updated shared Python environment: $python_env_dir"
    fi
  else
    add_status skipped 'Could not create the shared Python 3.13 environment'
    return
  fi
  if run "$python_env_dir/bin/python" -m pip install --upgrade pip pipx; then
    if "$DRY_RUN"; then
      add_status pending 'Would install pip and pipx in the shared Python environment'
    else
      add_status done 'Installed pip and pipx in the shared Python environment'
    fi
  else
    add_status skipped 'Could not install pip and pipx'
    return
  fi
  if run "$python_env_dir/bin/pipx" ensurepath; then
    if "$DRY_RUN"; then
      add_status pending 'Would configure the pipx application path'
    else
      add_status done 'Configured the pipx application path'
    fi
  else
    add_status skipped 'Could not configure the pipx application path'
  fi
}

configure_default_zsh() {
  local zsh_path current_shell current_user listed_shell
  local zsh_is_approved=false

  # A login shell is an account-level setting, distinct from the shell running
  # this installer. Use only a Zsh executable approved in /etc/shells, then
  # change the current user's future sessions through chsh.
  zsh_path="$(command -v zsh 2>/dev/null || true)"
  if [[ -z "$zsh_path" ]]; then
    add_status pending 'Install Zsh, then rerun setup to make it the default shell'
    return
  fi
  if [[ ! -r /etc/shells ]]; then
    add_status pending 'Confirm Zsh is an approved login shell, then run chsh manually'
    return
  fi
  while IFS= read -r listed_shell; do
    [[ "$listed_shell" == "$zsh_path" ]] && zsh_is_approved=true
  done < /etc/shells
  if ! "$zsh_is_approved" && [[ -x /bin/zsh ]]; then
    while IFS= read -r listed_shell; do
      if [[ "$listed_shell" == /bin/zsh ]]; then
        zsh_path=/bin/zsh
        zsh_is_approved=true
        break
      fi
    done < /etc/shells
  fi
  if ! "$zsh_is_approved"; then
    add_status pending "Add $zsh_path to /etc/shells, then run: chsh -s $zsh_path"
    return
  fi

  current_user="$(id -un)"
  case "$(uname -s)" in
    Darwin) current_shell="$(dscl . -read "/Users/$current_user" UserShell 2>/dev/null | awk '/UserShell:/ {print $2}')" ;;
    Linux) current_shell="$(getent passwd "$current_user" | cut -d: -f7)" ;;
    *) add_status skipped 'Default shell configuration: unsupported platform'; return ;;
  esac
  if [[ "$current_shell" == "$zsh_path" ]]; then
    add_status done "Default login shell is already Zsh: $zsh_path"
    return
  fi
  if "$DRY_RUN"; then
    add_status pending "Would change the default login shell to: $zsh_path"
    return
  fi
  if [[ ! -t 0 ]] || ! command -v chsh >/dev/null 2>&1; then
    add_status pending "Run interactively: chsh -s $zsh_path"
    return
  fi
  if chsh -s "$zsh_path"; then
    add_status done "Changed default login shell to Zsh: $zsh_path"
  else
    add_status pending "Could not change login shell; run: chsh -s $zsh_path"
  fi
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
configure_default_zsh
setup_python

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

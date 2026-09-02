# Login-shell environment shared by macOS and Linux.
# Python should be installed and selected by the operating system or a project
# tool such as uv; hard-coding a macOS framework version is not portable.
export PATH="$HOME/.local/bin:$PATH"

# The setup script creates this seeded environment with Python 3.13, pip, and
# pipx. Use it when present without changing the operating system's Python.
if [[ -d "$HOME/.venv/python-3.13/bin" ]]; then
  export PATH="$HOME/.venv/python-3.13/bin:$PATH"
fi

# Homebrew exists in different locations on Intel and Apple Silicon Macs.
# Ask its executable for the appropriate environment only when it is installed.
if command -v brew >/dev/null 2>&1; then
  eval "$(brew shellenv)"
fi

# Login-shell environment shared by macOS and Linux.
# Python should be installed and selected by the operating system or a project
# tool such as uv; hard-coding a macOS framework version is not portable.
export PATH="$HOME/.local/bin:$PATH"

# Homebrew exists in different locations on Intel and Apple Silicon Macs.
# Ask its executable for the appropriate environment only when it is installed.
if command -v brew >/dev/null 2>&1; then
  eval "$(brew shellenv)"
fi

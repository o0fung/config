# ~/.zshrc

# Where your zsh config lives
ZSH_DIR="${XDG_CONFIG_HOME:-$HOME/.zsh}"

# Helper: source a file if it exists
source_if_exists() {
  [[ -r "$1" ]] && source "$1"
}

# Optional: keep module file names explicit + ordered
source_if_exists "$ZSH_DIR/env.zsh"
source_if_exists "$ZSH_DIR/tools.zsh"
source_if_exists "$ZSH_DIR/aliases.zsh"
source_if_exists "$ZSH_DIR/functions.zsh"
source_if_exists "$ZSH_DIR/completion.zsh"

export STM32CubeMX_PATH=/Applications/STMicroelectronics/STM32CubeMX.app/Contents/Resources
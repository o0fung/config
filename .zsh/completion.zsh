# Completion is interactive-only and loads after VENV_HOME is established.
[[ -o interactive ]] || return
autoload -Uz compinit
zsh_cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/zsh"
mkdir -p "$zsh_cache_dir"
compinit -d "$zsh_cache_dir/zcompdump"

_venv() {
  local -a envdirs envs
  envdirs=( "$VENV_HOME"/*(N/) )
  envs=( "${envdirs:t}" )
  _describe -t venvs 'virtual environments' envs
}
compdef _venv venv

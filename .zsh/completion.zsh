# ~/.zsh/completion.zsh

autoload -Uz compinit
compinit

_venv() {
  local -a envdirs envs
  envdirs=( "$VENV_HOME"/*(N/) )
  envs=( ${envdirs:t} )
  _describe -t venvs "virtualenvs" envs
}
compdef _venv venv

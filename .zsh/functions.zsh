# ~/.zsh/functions.zsh

# Useful functions to run in zsh

: "${VENV_HOME:=$HOME/venv}"

#------------------------------------------------
# Load virtual environment from the ~/venv folder

# Base directory  envs (customizable)
: "${VENV_HOME:=$HOME/venv}"

venv() {
  local env="$1"
  local activate
  local -a envdirs

  # No args: list envs under $VENV_HOME
  if [[ -z "$env" ]]; then
    envdirs=( "$VENV_HOME"/*(N/) )
    if (( ${#envdirs} == 0 )); then
      print -r -- "(no envs in $VENV_HOME)"
      return 0
    fi
   
     # list directories only
     print -rl -- ${envdirs:t}
    return 0
  fi

  # Resolve activate script
  activate="$VENV_HOME/$env/bin/activate"
  if [[ ! -r "$activate" ]]; then
    print -u2 "venv: not found: $activate"
    return 1
  fi

 
   # Auto-deactivate if a venv is active
   if (( ${+VIRTUAL_ENV} )) && typeset -f deactivate >/dev/null; then
    deactivate
  fi

  source "$activate"
}

# Search file content and open file using fuzzy pattern matching
# ftxt [query]
ftxt() {
  local initial_query="$*"

  fzf --ansi --disabled --query "$initial_query" \
      --prompt 'rg> ' \
      --delimiter ':' --with-nth 3.. \
      --bind "change:reload:( [[ -n {q} ]] \
        && rg --line-number --no-heading --hidden --glob '!.git/*' --color=always --smart-case -- {q} \
        || true )" \
      --preview 'bat --color=always --style=numbers --highlight-line {2} {1}' \
      --bind 'enter:become(cursor --goto {1}:{2})'
}
alias ft='ftxt'

# Search file name and open file using fuzzy pattern matching
# ffile
ffile() {
  local q="${1-}"
  local sel dir

  sel="$(
    command fzf --exit-0 --ignore-case --scheme=path --tiebreak=begin,length \
      --prompt 'home> ' --query "$q" \
      --bind 'start:reload:command fd -t f -t d --exclude .git --exclude node_modules --exclude dist --exclude build . 2>/dev/null'
  )" || return

  [[ -z "$sel" ]] && return

  sel="${sel%$'\r'}"
  sel="${sel:a}"  # absolute path (no symlink resolution)

  if [[ -d "$sel" ]]; then
    dir="$sel"
    command zoxide add -- "$dir" 2>/dev/null || true
    builtin cd -- "$dir" || return
  else
    dir="${sel:h}"
    command zoxide add -- "$dir" 2>/dev/null || true
    builtin cd -- "$dir" || return
    command open -- "$sel"
  fi
}

alias ff='ffile'

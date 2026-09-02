# Personal shell workflows. Set VENV_HOME before loading this file to use a
# virtual-environment directory other than ~/venv.
: "${VENV_HOME:=$HOME/venv}"

_require_commands() {
  local command_name
  for command_name in "$@"; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
      print -u2 -- "Missing required command: $command_name"
      return 1
    fi
  done
}

_bat_command() {
  command -v bat >/dev/null 2>&1 && { print -r -- bat; return; }
  command -v batcat >/dev/null 2>&1 && { print -r -- batcat; return; }
  return 1
}

_fd_command() {
  command -v fd >/dev/null 2>&1 && { print -r -- fd; return; }
  command -v fdfind >/dev/null 2>&1 && { print -r -- fdfind; return; }
  return 1
}

_open_file() {
  case "$(uname -s)" in
    Darwin) open -- "$1" ;;
    Linux) xdg-open -- "$1" ;;
    *) print -u2 'Opening files is unsupported on this platform.'; return 1 ;;
  esac
}

# venv [name]
# Without a name, list environments. With a name, deactivate an existing
# environment before activating the requested one, preventing nested state.
venv() {
  local env="$1"
  local activate
  local -a envdirs

  if [[ -z "$env" ]]; then
    envdirs=( "$VENV_HOME"/*(N/) )
    (( ${#envdirs} )) || { print -r -- "(no envs in $VENV_HOME)"; return 0; }
    print -rl -- "${envdirs:t}"
    return 0
  fi

  activate="$VENV_HOME/$env/bin/activate"
  if [[ ! -r "$activate" ]]; then
    print -u2 -- "venv: not found: $activate"
    return 1
  fi
  if (( ${+VIRTUAL_ENV} )) && typeset -f deactivate >/dev/null; then
    deactivate
  fi
  source "$activate"
}

# ftxt [query]
# fzf reloads ripgrep results whenever the query changes, previews the matched
# line with bat, and replaces itself with Cursor only after Enter is pressed.
ftxt() {
  local initial_query="$*"
  local bat_command
  _require_commands fzf rg cursor || return
  bat_command="$(_bat_command)" || { print -u2 'ftxt also requires bat.'; return 1; }

  fzf --ansi --disabled --query "$initial_query" \
    --prompt 'rg> ' \
    --delimiter ':' --with-nth 3.. \
    --bind "change:reload:( [[ -n {q} ]] && rg --line-number --no-heading --hidden --glob '!.git/*' --color=always --smart-case -- {q} || true )" \
    --preview "$bat_command --color=always --style=numbers --highlight-line {2} {1}" \
    --bind 'enter:become(cursor --goto {1}:{2})'
}
alias ft='ftxt'

# ffile [query]
# Search files and directories, then either navigate to a directory or open a
# selected file. Add the containing directory to zoxide only when it exists.
ffile() {
  local query="${1-}"
  local selected directory fd_command
  _require_commands fzf || return
  fd_command="$(_fd_command)" || { print -u2 'ffile requires fd.'; return 1; }

  selected="$(
    fzf --exit-0 --scheme=path --tiebreak=begin,length \
      --prompt 'files> ' --query "$query" \
      --bind "start:reload:$fd_command -t f -t d --exclude .git --exclude node_modules --exclude dist --exclude build . 2>/dev/null"
  )" || return
  [[ -n "$selected" ]] || return

  selected="${selected%$'\r'}"
  selected="${selected:a}"
  if [[ -d "$selected" ]]; then
    directory="$selected"
  else
    directory="${selected:h}"
  fi
  command -v zoxide >/dev/null 2>&1 && zoxide add -- "$directory"
  builtin cd -- "$directory" || return
  [[ -f "$selected" ]] && _open_file "$selected"
}
alias ff='ffile'

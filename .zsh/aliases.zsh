# Friendly command replacements. Each alias is conditional so the standard
# command remains available until its optional replacement is installed.
if command -v eza >/dev/null 2>&1; then
  alias ls='eza'
  alias ll='eza -l --git --git-repos --header --color-scale=all'
  alias la='ll -a'
  alias tree='ll --tree'
fi

if command -v bat >/dev/null 2>&1; then
  alias cat='bat'
elif command -v batcat >/dev/null 2>&1; then
  alias cat='batcat'
fi

command -v zoxide >/dev/null 2>&1 && alias cd='z'
command -v zoxide >/dev/null 2>&1 && alias ..='z ..'
command -v micro >/dev/null 2>&1 && alias nano='micro'
command -v python3 >/dev/null 2>&1 && alias py='python3'

# Open the current directory in the platform's default application rather
# than forcing a macOS-only Chrome file URL.
idx() {
  case "$(uname -s)" in
    Darwin) open "$PWD" ;;
    Linux) xdg-open "$PWD" ;;
    *) print -u2 'idx: unsupported platform' ; return 1 ;;
  esac
}

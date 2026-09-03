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

# Open the current directory as a browser file listing so files (e.g. markdown)
# can be opened with browser extensions rather than the system file manager.
idx() {
  case "$(uname -s)" in
    Darwin) open -a "Google Chrome" "file://$PWD/" ;;
    Linux)
      local url="file://$PWD/"
      if command -v google-chrome >/dev/null 2>&1; then
        google-chrome "$url"
      elif command -v chromium >/dev/null 2>&1; then
        chromium "$url"
      else
        xdg-open "$url"
      fi
      ;;
    *) print -u2 'idx: unsupported platform' ; return 1 ;;
  esac
}

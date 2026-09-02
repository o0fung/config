# Interactive prompt and portable environment defaults.
PS1='%F{green}%n@%m %F{yellow}%~%f %(?.%F{green}.%F{red})%#%f '

export PATH="$HOME/.local/bin:$PATH"

# BSD ls (macOS) uses LSCOLORS; GNU ls (Linux) uses LS_COLORS. Only set the
# matching variable so a macOS-specific color code is never sent to GNU ls.
case "$(uname -s)" in
  Darwin) export CLICOLOR=1 LSCOLORS='Gxfxcxdxbxegedabagacad' ;;
  Linux) export CLICOLOR=1 ;;
esac

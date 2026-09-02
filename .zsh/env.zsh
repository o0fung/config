# ~/.zsh/env.zsh

#PS1="%F{green}%n@%m %F{yellow}%~ %F{red}$ %F{reset}"
PS1='%F{green}%n@%m %F{yellow}%~%f %(?.%F{green}.%F{red})%#%f '

export CLICOLOR=1
export LSCOLORS=gxFxCxDxBxegedabagaced
export LSCOLORS=Gxfxcxdxbxegedabagacad

# Personal scripts
export PATH="$HOME/.local/bin:$PATH"

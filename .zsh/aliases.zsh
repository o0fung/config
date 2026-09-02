# ~/.zsh/aliaees.zsh

# Setup useful aliases

# Use EZA to replace ls
alias ls='eza'
alias ll='eza -l --git --git-repos --header --color-scale=all'
alias la='ll -a'
alias tree='ll --tree'

# Replacement of standard zsh tools
alias cat='bat'
alias cd='z'
alias ..='z ..'
alias nano='micro'

# Shortcut to open Markdown files
alias idx='open -a "Google Chrome" "file://$PWD/"'

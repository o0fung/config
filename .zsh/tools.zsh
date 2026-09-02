# ~/.zsh/tools.zsh

# Define an interactive function for zoxide
[[ -o interactive ]] || return
eval "$(zoxide init zsh)"

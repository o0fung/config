# Third-party shell integrations are optional. Missing tools must not prevent
# a new shell from starting successfully.
[[ -o interactive ]] || return

if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
fi

if command -v direnv >/dev/null 2>&1; then
  eval "$(direnv hook zsh)"
fi


# Setting PATH for Python 3.13
# The original version is saved in .zprofile.pysave
PATH="/Library/Frameworks/Python.framework/Versions/3.13/bin:${PATH}"
export PATH

alias py='python3'
eval "$(/opt/homebrew/bin/brew shellenv)"

# Personal scripts
export PATH="$HOME/.local/bin:$PATH"

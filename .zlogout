# This runs right before loggin out of a login shell
# Load order:
# - .zshenv
# - .zprofile (login only)
# - .zshrc (interactive only)
# - .zlogin (login only)
# - .zlogout (logout only)

[ -f ~/.zlogout.local ] && source ~/.zlogout.local

export _ZLOGOUT_LOADED=$(( ${_ZLOGOUT_LOADED:-0} + 1 ))

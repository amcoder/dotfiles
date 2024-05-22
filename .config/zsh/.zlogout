# This runs right before logging out of a login shell
# Load order:
# - .zshenv
# - .zprofile (login only)
# - .zshrc (interactive only)
# - .zlogin (login only)
# - .zlogout (logout only)

[ -f ~/.zlogout.local ] && source ~/.zlogout.local

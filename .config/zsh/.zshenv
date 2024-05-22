# This is loaded first for all zsh instances
# Load order:
# - .zshenv
# - .zprofile (login only)
# - .zshrc (interactive only)
# - .zlogin (login only)
# - .zlogout (logout only)

[ -f ~/.zshenv.local ] && source ~/.zshenv.local

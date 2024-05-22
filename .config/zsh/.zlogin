# This is loaded last for login shells
# Load order:
# - .zshenv
# - .zprofile (login only)
# - .zshrc (interactive only)
# - .zlogin (login only)
# - .zlogout (logout only)

[ -f "$ZDOTDIR/.zlogin.local" ] && source "$ZDOTDIR/.zlogin.local"

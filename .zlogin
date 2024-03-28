# This is loaded last for login shells
# Load order:
# - .zshenv
# - .zprofile (login only)
# - .zshrc (interactive only)
# - .zlogin (login only)
# - .zlogout (logout only)

[ -f ~/.zlogin.local ] && source ~/.zlogin.local

export _ZLOGIN_LOADED=1:$_ZLOGIN_LOADED

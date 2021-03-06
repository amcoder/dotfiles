# This is loaded after .zshenv but before .zshrc for login shells
# Load order:
# - .zshenv
# - .zprofile (login only)
# - .zshrc (interactive only)
# - .zlogin (login only)
# - .zlogout (logout only)

# Load ~/.profile to get any general login settings
[[ -f ~/.profile ]] && emulate sh -c '. ~/.profile'


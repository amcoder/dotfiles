# This is loaded after .zshenv but before .zshrc for login shells
# Load order:
# - .zshenv
# - .zprofile (login only)
# - .zshrc (interactive only)
# - .zlogin (login only)
# - .zlogout (logout only)

# Keep everyhting in .profile and just source it from here
[ -f "$HOME/.profile" ] && source "$HOME/.profile"

[ -f "$ZDOTDIR/.zprofile.local" ] && source "$ZDOTDIR/.zprofile.local"

# This is loaded after .zshenv but before .zshrc for login shells
# Load order:
# - .zshenv
# - .zprofile (login only)
# - .zshrc (interactive only)
# - .zlogin (login only)
# - .zlogout (logout only)

# Keep everyhting in .profile and just source it from here
[ -f ~/.profile ] && source ~/.profile

[ -f ~/.zprofile.local ] && source ~/.zprofile.local

export _ZPROFILE_LOADED=1:$_ZPROFILE_LOADED

[ -s "$NVM_DIR/nvm.sh" ] || return 0

# deferred loading of nvm
zsh-defer source "$NVM_DIR/nvm.sh"

# Load node version from .nvmrc if available
load-nvmrc() {
  local nvmrc_path="$(nvm_find_nvmrc)"

  [ "$OLD_NVMRC_PATH" = "$nvmrc_path" ] && return

  if [ -n "$nvmrc_path" ]; then
    local nvmrc_node_version=$(nvm version "$(cat "${nvmrc_path}")")

    if [ "$nvmrc_node_version" = "N/A" ]; then
      nvm install
    elif [ "$nvmrc_node_version" != "$(nvm version)" ]; then
      nvm use --silent
    fi
  elif [ -n "$OLD_NVMRC_PATH" ] && [ "$(nvm version)" != "$(nvm version default)" ]; then
    nvm use default --silent
  fi

  OLD_NVMRC_PATH=$nvmrc_path
}

autoload -U add-zsh-hook
add-zsh-hook chpwd load-nvmrc
zsh-defer load-nvmrc

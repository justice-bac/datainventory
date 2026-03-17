# Performance optimizations
DISABLE_AUTO_UPDATE="true"
DISABLE_MAGIC_FUNCTIONS="true"
DISABLE_COMPFIX="true"

# Cache completions aggressively
autoload -Uz compinit
if [ -f ~/.zcompdump ] && [ "$(date +'%j')" = "$(date -r ~/.zcompdump +'%j' 2>/dev/null)" ]; then
    compinit -C
else
    compinit
fi

# Oh My Zsh path
export ZSH="$HOME/.oh-my-zsh"

# Theme config
ZSH_THEME="spaceship"

# Spaceship settings
SPACESHIP_PROMPT_ASYNC=true
SPACESHIP_PROMPT_ADD_NEWLINE=true
SPACESHIP_CHAR_SYMBOL="⚡"

# Minimal spaceship sections for performance
SPACESHIP_PROMPT_ORDER=(
  time
  user
  dir
  git
  line_sep
  char
)

# Carefully ordered plugins (syntax highlighting must be last)
plugins=(
  git
  zsh-autosuggestions
  zsh-syntax-highlighting
)

# Source Oh My Zsh
source $ZSH/oh-my-zsh.sh

# Autosuggest settings
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#663399,standout"
ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE="20"
ZSH_AUTOSUGGEST_USE_ASYNC=1

# Alias expansion function
globalias() {
   if [[ $LBUFFER =~ '[a-zA-Z0-9]+$' ]]; then
       zle _expand_alias
       zle expand-word
   fi
   zle self-insert
}
zle -N globalias
bindkey " " globalias
bindkey "^[[Z" magic-space
bindkey -M isearch " " magic-space

# Lazy load SSH agent
function _load_ssh_agent() {
    if [ -z "$SSH_AUTH_SOCK" ]; then
        eval "$(ssh-agent -s)" > /dev/null
        ssh-add ~/.ssh/id_github_sign_and_auth 2>/dev/null
    fi
}

# Sync Azure subscription to ARM_SUBSCRIPTION_ID before each prompt
_sync_azure_subscription_env() {
    if ! command -v az >/dev/null 2>&1; then
        return
    fi

    local subscription_id
    subscription_id="$(command az account show --query id -o tsv 2>/dev/null || true)"

    if [[ -n "$subscription_id" ]]; then
        export ARM_SUBSCRIPTION_ID="$subscription_id"
    else
        unset ARM_SUBSCRIPTION_ID
    fi
}

autoload -U add-zsh-hook
add-zsh-hook precmd _load_ssh_agent
add-zsh-hook precmd _sync_azure_subscription_env

# Set locale
export LC_ALL=C.UTF-8
export LANG=C.UTF-8
export LANGUAGE=C.UTF-8

# Source aliases last
[ -f ~/.zsh_aliases ] && source ~/.zsh_aliases
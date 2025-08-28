export PATH="$HOME/.local/share/omarchy/bin:$PATH"
# All the default Omarchy aliases and functions
# (don't mess with these directly, just overwrite them here!)
source ~/.local/share/omarchy/default/bash/rc

# Add your own exports, aliases, and functions here.
#
# Make an alias for invoking commands you use constantly
# alias p='python'
#
# Use VSCode instead of neovim as your default editor
# export EDITOR="code"
#
# Set a custom prompt with the directory revealed (alternatively use https://starship.rs)
# PS1="\W \[\e]0;\w\a\]$PS1"
#

# -- DOTBARE -------------------------------------------------------------------

export PATH=$PATH:$HOME/.dotbare

export DOTBARE_DIR="$HOME/.cfg/"
export DOTBARE_TREE="$HOME"
export DOTBARE_BACKUP="${XDG_DATA_HOME:-$HOME/.local/share}/dotbare"
export DOTBARE_FZF_DEFAULT_OPTS="--preview-window=right:65%"
export DOTBARE_KEY="
  --bind=alt-a:toggle-all
  --bind=alt-w:jump
  --bind=alt-0:top
  --bind=alt-s:toggle-sort
  --bind=alt-t:toggle-preview
"

# GitHub SSH Agent Configuration (generado automáticamente)
if [ -f ~/.ssh/id_ed25519 ]; then
    eval "$(ssh-agent -s)" &>/dev/null
    ssh-add ~/.ssh/id_ed25519 &>/dev/null
fi

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
# Source the Lazyman shell initialization for aliases and nvims selector
# shellcheck source=.config/nvim-Lazyman/.lazymanrc
[ -f ~/.config/nvim-Lazyman/.lazymanrc ] && source ~/.config/nvim-Lazyman/.lazymanrc
# Source the Lazyman .nvimsbind for nvims key binding
# shellcheck source=.config/nvim-Lazyman/.nvimsbind
[ -f ~/.config/nvim-Lazyman/.nvimsbind ] && source ~/.config/nvim-Lazyman/.nvimsbind
# Luarocks bin path
[ -d ${HOME}/.luarocks/bin ] && {
  export PATH="${HOME}/.luarocks/bin${PATH:+:${PATH}}"
}





# --- INICIO DE CONFIGURACION DE DEVTOOLS (gestionado por script) ---
# Asegurarse de que ~/.local/bin está en el PATH para herramientas como pipx, proselint, vint
[ -d "${HOME}/.local/bin" ] && { export PATH="${HOME}/.local/bin${PATH:+:${PATH}}"; }

# Asegurarse de que los binarios de Go instalados por 'go install' estén en el PATH
[ -d "${HOME}/go/bin" ] && { export PATH="${HOME}/go/bin${PATH:+:${PATH}}"; }

# Asegurarse de que los binarios de Cargo (Rust) estén en el PATH
[ -d "${HOME}/.cargo/bin" ] && { export PATH="${HOME}/.cargo/bin${PATH:+:${PATH}}"; }

# Asegurarse de que los paquetes globales de NPM estén en el PATH
# (Si configuraste un prefijo npm diferente, ajusta la ruta)
[ -d "$(npm config get prefix)/bin" ] && { export PATH="$(npm config get prefix)/bin${PATH:+:${PATH}}"; }

# Asegurarse de que los binarios de Ruby Gems estén en el PATH
# (La versión de Ruby puede variar, ajusta si es necesario)
[ -d "${HOME}/.local/share/gem/ruby/3.4\.0/bin" ] && { export PATH="${HOME}/.local/share/gem/ruby/3.4\.0/bin${PATH:+:${PATH}}"; }

# --- FIN DE CONFIGURACION DE DEVTOOLS ---

# Añadir snap al PATH si la carpeta existe
if [ -d "/var/lib/snapd/snap/bin" ]; then
    export PATH="$PATH:/var/lib/snapd/snap/bin"
fi


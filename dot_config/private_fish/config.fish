if status is-interactive
    # Commands to run in interactive sessions can go here

    # Aliases (using abbreviations for better experience)
    abbr -a ll 'ls -alF'
    abbr -a la 'ls -A'
    abbr -a l 'ls -CF'
    abbr -a grep 'grep --color=auto'
    abbr -a ml 'make -f Makefile.local'
    abbr -a fgrep 'fgrep --color=auto'
    abbr -a egrep 'egrep --color=auto'

    # ls with colors is default in fish, but ensure it
    alias ls 'ls --color=auto'
end

# Editor
set -gx EDITOR nvim

# Source secrets (not tracked in dotfiles)
if test -f ~/.secrets
    source ~/.secrets
end

# PATH additions — each guarded so the same config works on every machine.
# fish_add_path prepends, so later entries win.
test -d /usr/local/bin; and fish_add_path /usr/local/bin
test -d $HOME/.rebar/current/bin; and fish_add_path $HOME/.rebar/current/bin
test -d $HOME/.local/bin; and fish_add_path $HOME/.local/bin
test -d $HOME/.pyenv/bin; and fish_add_path $HOME/.pyenv/bin
# go comes from Homebrew (/opt/homebrew/bin) on macOS and /usr/local/go/bin on Linux;
# $HOME/go/bin holds GOPATH tools
test -d /opt/homebrew/bin; and fish_add_path /opt/homebrew/bin
test -d /usr/local/go/bin; and fish_add_path /usr/local/go/bin
test -d $HOME/go/bin; and fish_add_path $HOME/go/bin

# NVM node path (ensures NVM's node takes priority over system nodejs)
set -l nvm_default_path "$HOME/.nvm/versions/node/v22.13.1/bin"
if test -d $nvm_default_path
    fish_add_path $nvm_default_path
end

# NVM setup for fish
# Option 1: Use nvm.fish (recommended) - install via:
#   fisher install jorgebucaran/nvm.fish
# Option 2: Use bass to run bash nvm (slower):
set -gx NVM_DIR "$HOME/.nvm"
# If you install bass (fisher install edc/bass), uncomment:
# bass source $NVM_DIR/nvm.sh

# Pyenv setup
if command -q pyenv
    pyenv init --path | source
    pyenv init - | source
end


set -gx PATH "$HOME/.local/bin" $PATH
fnm env --shell fish | source

### Posh Setup
oh-my-posh init --config "~/.config/fish/themes/bubbleleft.json" fish | source

if command -q direnv
    direnv hook fish | source
end

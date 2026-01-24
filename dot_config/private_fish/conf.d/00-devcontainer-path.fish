# Ensure dev tools are in PATH (for devcontainer)
if test -d /home/dev/.local/share/fnm
    set -gx PATH /home/dev/.local/bin /home/dev/.local/share/fnm /home/dev/go/bin /usr/local/go/bin $PATH
    fnm env --shell fish 2>/dev/null | source
end

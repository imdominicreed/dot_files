function _p_preview --argument-names dir --description 'fzf preview pane for p'
    set -l session (string replace -ar '[.:]' '_' -- (basename $dir))

    if tmux has-session -t "=$session" 2>/dev/null
        set_color green
        echo "● session running"
        set_color normal
        tmux list-windows -t "=$session" -F '  #{window_index}:#{window_name}#{?window_active, *,}'
    else
        set_color brblack
        echo "○ not started"
        set_color normal
    end

    echo
    set_color brblack
    echo $dir
    set_color normal
    command ls -A --color=always $dir | head -40
end

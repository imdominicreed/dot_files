function p --description 'Open or attach a tmux session for a project'
    if contains -- "$argv[1]" -h --help
        echo "p             pick a project with fzf"
        echo "p <name>      jump to a project (exact name wins, else fuzzy)"
        echo "p .           use the current directory"
        echo "p <path>      use any directory"
        echo
        echo "Projects come from \$PROJECTS_DIR (default ~/projects)."
        echo "A new session gets: 1:edit (nvim)  2:shell  3:claude"
        return 0
    end

    set -l root $PROJECTS_DIR
    test -n "$root"; or set root $HOME/projects

    # Resolve the target directory
    set -l dir
    if test (count $argv) -gt 0; and test -d "$argv[1]"
        # An explicit path (including ".") wins over the project list
        set dir (realpath $argv[1])
    else
        if not test -d $root
            echo "p: no such directory: $root" >&2
            return 1
        end

        set -l projects (_p_projects $root)
        if test -z "$projects"
            echo "p: no projects found in $root" >&2
            return 1
        end

        set -l name
        if contains -- "$argv[1]" $projects
            # Exact name beats any fuzzy match
            set name $argv[1]
        else
            set name (printf '%s\n' $projects | fzf \
                --query="$argv[1]" --select-1 --exit-0 \
                --prompt='project> ' --height=40% --reverse \
                --preview="fish -c '_p_preview \"$root/{}\"'" \
                --preview-window=right:55%)
        end

        test -n "$name"; or return 1
        set dir $root/$name
    end

    # tmux session names can't contain "." or ":"
    set -l session (string replace -ar '[.:]' '_' -- (basename $dir))

    if not tmux has-session -t "=$session" 2>/dev/null
        tmux new-session -d -s $session -c $dir -n edit
        tmux send-keys -t "=$session:edit" 'nvim .' Enter

        tmux new-window -t "=$session" -c $dir -n shell

        if command -q claude
            tmux new-window -t "=$session" -c $dir -n claude
            tmux send-keys -t "=$session:claude" claude Enter
        end

        tmux select-window -t "=$session:edit"
    end

    if set -q TMUX
        tmux switch-client -t "=$session"
    else
        tmux attach-session -t "=$session"
    end
end

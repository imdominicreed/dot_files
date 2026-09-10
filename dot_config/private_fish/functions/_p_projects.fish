function _p_projects --argument-names root --description 'List project dirs, most recently touched first'
    test -n "$root"; or set root $PROJECTS_DIR
    test -n "$root"; or set root $HOME/projects
    test -d $root; or return 1

    command find $root -maxdepth 1 -mindepth 1 -type d \
        -not -name '.*' -not -name '__pycache__' -printf '%T@ %f\n' \
        | sort -rn | string replace -r '^\S+ ' ''
end

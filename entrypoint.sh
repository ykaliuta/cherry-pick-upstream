#!/bin/bash

set -e

UPSTREAM=$1
DOWNSTREAM=$2
EXCLUDES_FILE=$3

setup_git()
{
    git config --global --add safe.directory /github/workspace
    git config user.name "${GITHUB_ACTOR}"
    git config user.email "${GITHUB_ACTOR}@users.noreply.github.com"

    git checkout $DOWNSTREAM
}

make_message()
{
    local commit=$1
    local hash

    git log -1 --pretty=%B $commit
    hash=$(git log -1 --pretty=%H $commit)
    echo "(cherry picked from commit $hash)"
}

cherry_pick_commit()
{
    local commit=$1
    local author="$(git log -1 --pretty=%an $commit)"
    local date="$(git log -1 --pretty=%ad $commit)"
    local exclude_arg

    if [[ -n $EXCLUDES_FILE ]]; then
        exclude_arg="-X $EXCLUDES_FILE"
    fi

    git format-patch -1 --stdout --no-prefix $commit | \
        filterdiff $exclude_arg | \
        git apply -p0 --index --whitespace=warn --allow-empty -
    make_message $commit | \
        git commit --allow-empty --author="$author" --date="$date" -F -
}

upstream_from_cherry_pick()
{
    local commit=$1
    local upstream

    upstream=$(git log -1 --pretty=%b $commit \
               | sed -n -e "/^(cherry picked/{s/.* \([0-9a-f]*\))/\1/;p}" \
               | tail -1)

    echo "$upstream"
}

# last backported commit is the first one cherry-picked
get_last_backported_commit()
{
    local branch=$1
    local upstream

    git log --pretty=%H $1 | while read c; do
        upstream=$(upstream_from_cherry_pick $c)
        if [[ -n $upstream ]]; then
            echo $upstream
            exit 0
        fi
    done
}

do_backport()
{
    local from=$1
    local to=$2
    local count=$(git rev-list --count $from..$to)

    if [[ $count = 0 ]]; then
        echo "No commits to backport from $from to $to"
        return
    fi

    git log --reverse --pretty=%H $from..$to | while read c; do
        echo "Applying $(git log -1 --pretty=oneline $c)"
        cherry_pick_commit $c
    done
}

setup_git
do_backport $(get_last_backported_commit HEAD) $UPSTREAM

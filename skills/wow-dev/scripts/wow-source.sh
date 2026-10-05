#!/bin/sh
# Print the local path and build of one flavor branch of a trusted WoW source repo,
# cloning it on first use and refreshing it at most once a day.
# Usage: wow-source.sh <ui|res|wa> <branch>

set -e

usage="usage: wow-source.sh <ui|res|wa> <branch>"

# The allowlist doubles as the trust boundary, no other repo is ever fetched
case "$1" in
    ui) repo=Gethe/wow-ui-source ;;
    res) repo=Ketho/BlizzardInterfaceResources ;;
    wa) repo=WeakAuras/WeakAuras2 ;;
    *) echo "$usage" >&2; exit 1 ;;
esac

branch=${2:?$usage}
dir="${XDG_CACHE_HOME:-$HOME/.cache}/wow-dev/$1/$branch"
stamp="$dir/.git/FETCH_HEAD"

if [ ! -d "$dir/.git" ]; then
    git clone -q --depth 1 --single-branch -b "$branch" "https://github.com/$repo.git" "$dir"
    touch "$stamp"
elif [ -n "$(find "$stamp" -mtime +0 2>/dev/null)" ] || [ ! -f "$stamp" ]; then
    git -C "$dir" fetch -q --depth 1 origin "$branch" && git -C "$dir" reset -q --hard FETCH_HEAD ||
        echo "refresh failed, using the cached copy" >&2
fi

echo "$dir"
git -C "$dir" log -1 --format='build: %s (%cs)'

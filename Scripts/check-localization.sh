#!/bin/bash
#
# Every key in one language exists in the other, and carries the same format
# specifiers.
#
# A missing key does not crash and does not warn — `Text("home.stops.add")` simply
# renders the key itself, or falls back to the development language, so an English
# reader silently gets a German sentence. A mismatched specifier is worse: "%1$d of
# %2$d" against a string expecting "%@" is a crash at runtime, in front of the
# traveller, in the language nobody on the team reads.
#
set -uo pipefail
cd "$(dirname "$0")/.."

base=Vihara/de.lproj/Localizable.strings
status=0

keys() {
    grep -oE '^"[^"]+"' "$1" | tr -d '"' | sort
}

specifiers() {
    # The format specifiers of one key's value, in order.
    grep -E "^\"$2\" *=" "$1" | sed 's/^[^=]*= *//' | grep -oE '%[0-9]*\$?[@dfs]' | tr '\n' ' '
}

for other in Vihara/*.lproj/Localizable.strings; do
    [ "$other" = "$base" ] && continue
    name=$(basename "$(dirname "$other")")

    echo "$name: every key from de is present"
    missing=$(comm -23 <(keys "$base") <(keys "$other"))
    if [ -n "$missing" ]; then
        echo "$missing" | sed 's/^/  ✘ missing: /'
        status=1
    fi

    echo "$name: no keys de does not have"
    extra=$(comm -13 <(keys "$base") <(keys "$other"))
    if [ -n "$extra" ]; then
        echo "$extra" | sed 's/^/  ✘ unknown: /'
        status=1
    fi

    echo "$name: format specifiers match"
    while read -r key; do
        [ -z "$key" ] && continue
        a=$(specifiers "$base" "$key")
        b=$(specifiers "$other" "$key")
        if [ "$a" != "$b" ]; then
            echo "  ✘ $key: de has [$a], $name has [$b]"
            status=1
        fi
    done < <(comm -12 <(keys "$base") <(keys "$other"))
done

if [ $status -eq 0 ]; then
    echo "✔ localizations agree"
fi
exit $status

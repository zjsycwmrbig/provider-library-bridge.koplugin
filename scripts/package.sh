#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
name="$(basename "$repo_dir")"
version="${VERSION:-$(sed -n 's/.*version = "\([^"]*\)".*/\1/p' "$repo_dir/_meta.lua" | head -n1)}"
archive="$repo_dir/dist/${name}-v${version}.zip"

mkdir -p "$repo_dir/dist"
rm -f "$archive"

stage="$(mktemp -d "${TMPDIR:-/tmp}/provider-library-package.XXXXXX")"
trap 'rm -rf "$stage"' EXIT
mkdir -p "$stage/$name"
cp "$repo_dir/_meta.lua" "$stage/$name/"
cp "$repo_dir/main.lua" "$stage/$name/"
cp "$repo_dir/README.md" "$stage/$name/"
cp -R "$repo_dir/provider_library" "$stage/$name/"
cp -R "$repo_dir/assets" "$stage/$name/"

if [ -f "$repo_dir/LICENSE" ]; then
    cp "$repo_dir/LICENSE" "$stage/$name/"
fi

(
    cd "$stage"
    zip -r -q "$archive" "$name"
)

unzip -t "$archive" >/dev/null
printf '%s\n' "$archive"

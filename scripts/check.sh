#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
cd "$repo_dir"

lua_bin="${LUA_BIN:-}"
if [ -z "$lua_bin" ]; then
    for candidate in luajit lua5.1 lua; do
        if command -v "$candidate" >/dev/null 2>&1; then
            lua_bin="$candidate"
            break
        fi
    done
fi
if [ -z "$lua_bin" ]; then
    echo 'Install LuaJIT or Lua 5.1, or set LUA_BIN.' >&2
    exit 1
fi

while IFS= read -r -d '' file; do
    BRIDGE_LUA_FILE="$file" "$lua_bin" -e 'assert(loadfile(os.getenv("BRIDGE_LUA_FILE")))'
done < <(find main.lua _meta.lua provider_library spec scripts -name '*.lua' -type f -print0)

for spec in spec/*_spec.lua; do
    "$lua_bin" "$spec"
done
echo 'Lua syntax and regression checks passed.'

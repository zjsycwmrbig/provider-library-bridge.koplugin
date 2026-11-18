local files, removed, placeholders, index, snapshot, records, scan_error, fail_path
package.preload.docsettings = function() return {} end
package.preload.logger = function() return { warn = function() end } end
package.preload["libs/libkoreader-lfs"] = function() return { attributes = function() end } end
package.preload["provider_library.history"] = function()
    return { flush = function() end, reconcile = function() end }
end
package.preload["provider_library.util"] = function()
    return { file_exists = function(path) return files[path] ~= nil end }
end
package.preload["provider_library.placeholder"] = function()
    return {
        build_index = function() return index end,
        upsert = function() return "unchanged" end,
        is_owned = function(path, provider, id)
            return files[path].provider == provider and files[path].id == id
        end,
        matches_endpoint = function(path, scope) return files[path].scope == scope end,
        remove = function(path, history)
            assert(history == true)
            if path == fail_path then return false end
            removed[#removed + 1] = path
            files[path] = nil
            return true
        end,
    }
end
package.path = "./?.lua;" .. package.path
local Sync = require("provider_library.sync")
local scope = "http://fixture.test"
local settings = {
    get = function(_, _, default) return default end,
    all_placeholders = function() return placeholders end,
    remove_placeholder = function(_, provider, id) placeholders[provider][id] = nil end,
    flush = function() end,
}
local context = {
    ui = { suwayomi = {} }, settings = settings,
    providers = { { id = "suwayomi", plugin_name = "suwayomi", scan = function()
        if scan_error then error("invalid snapshot") end
        return records, snapshot
    end } },
}
local function reset()
    files, removed, index, records = {}, {}, {}, {}
    placeholders = { suwayomi = {} }
    snapshot = { endpoint_scope = scope, library_members = {} }
    scan_error, fail_path = nil, nil
    context.ui.document = nil
end
local function add(id, path, endpoint, provider)
    files[path] = { id = id, scope = endpoint or scope, provider = provider or "suwayomi" }
    placeholders.suwayomi[id] = { path = path }
end

reset()
add("old", "/books/old.html")
add("kept", "/books/kept.html")
snapshot.library_members.kept = true -- cached-only omission must preserve this
local report = Sync.run(context)
assert(report.removed == 1 and report.failed == 0)
assert(files["/books/old.html"] == nil and files["/books/kept.html"])
assert(placeholders.suwayomi.old == nil and placeholders.suwayomi.kept)
assert(Sync.run(context).removed == 0)

reset()
add("moved", "/books/folder/moved.html")
placeholders.suwayomi.moved.path = "/books/previous.html"
index.suwayomi = { moved = { { path = "/books/folder/moved.html" } } }
assert(Sync.run(context).removed == 1)
assert(files["/books/folder/moved.html"] == nil and placeholders.suwayomi.moved == nil)

reset()
add("a", "/books/a.html")
add("b", "/books/b.html", "http://foreign.test")
add("c", "/books/ordinary.html", scope, "other")
fail_path = "/books/a.html"
report = Sync.run(context)
assert(report.removed == 0 and report.failed == 1)
assert(files[fail_path] and placeholders.suwayomi.a)
assert(files["/books/b.html"] and placeholders.suwayomi.b)
assert(files["/books/ordinary.html"] and placeholders.suwayomi.c)

reset()
add("old", "/books/old.html")
scan_error = true
report = Sync.run(context)
assert(report.failed == 1 and report.removed == 0 and files["/books/old.html"])
scan_error, snapshot = false, nil
assert(Sync.run(context).removed == 0 and files["/books/old.html"])
snapshot = { endpoint_scope = scope, library_members = {} }
context.ui.document = { file = "/books/old.html" }
assert(Sync.run(context).removed == 0 and files["/books/old.html"])
context.ui.document = nil
assert(Sync.run(context).removed == 1)
print("sync_membership_spec: ok")

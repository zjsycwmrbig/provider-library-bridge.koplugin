local lfs = require("libs/libkoreader-lfs")

local Registry = {}

local REQUIRED_FIELDS = {
    id = "string",
    label = "string",
    tag = "string",
    plugin_name = "string",
    scan = "function",
    open = "function",
}

local function validate(provider, source)
    for key, expected_type in pairs(REQUIRED_FIELDS) do
        if type(provider[key]) ~= expected_type then
            error(string.format(
                "provider %s has invalid %s", tostring(source), key
            ))
        end
    end
end

function Registry.load(plugin_root)
    local directory = plugin_root .. "/provider_library/providers"
    local providers = {}
    local ok, iter, dir_obj = pcall(lfs.dir, directory)
    if not ok or type(iter) ~= "function" then
        return providers
    end

    for entry in iter, dir_obj do
        if entry:sub(-4) == ".lua" and entry:sub(1, 1) ~= "." then
            local module_name = entry:sub(1, -5)
            local loaded, provider = pcall(
                require, "provider_library.providers." .. module_name
            )
            if loaded and type(provider) == "table" then
                local valid, validation_error = pcall(validate, provider, entry)
                if valid then
                    providers[#providers + 1] = provider
                else
                    require("logger").warn(
                        "provider-library-bridge:", validation_error
                    )
                end
            elseif not loaded then
                require("logger").warn(
                    "provider-library-bridge: cannot load provider",
                    entry, tostring(provider)
                )
            end
        end
    end

    table.sort(providers, function(left, right)
        local lp = tonumber(left.priority) or 100
        local rp = tonumber(right.priority) or 100
        if lp == rp then
            return left.id < right.id
        end
        return lp < rp
    end)
    return providers
end

function Registry.by_id(providers, id)
    for _, provider in ipairs(providers or {}) do
        if provider.id == id then
            return provider
        end
    end
end

return Registry

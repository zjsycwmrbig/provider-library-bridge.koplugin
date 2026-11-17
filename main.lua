local ButtonDialog = require("ui/widget/buttondialog")
local Event = require("ui/event")
local InfoMessage = require("ui/widget/infomessage")
local NetworkMgr = require("ui/network/manager")
local PluginLoader = require("pluginloader")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local logger = require("logger")
local _ = require("gettext")

local BottomMessage = require("provider_library.bottom_message")
local Registry = require("provider_library.registry")
local Settings = require("provider_library.settings")
local Sync = require("provider_library.sync")
local UIPatch = require("provider_library.ui_patch")
local U = require("provider_library.util")

local PLUGIN_NAME = "provider-library-bridge"
local AUTO_CHECK_INTERVAL = 60

local scheduler_started = false
local auto_sync_running = false

local ProviderLibraryBridge = WidgetContainer:extend{
    name = PLUGIN_NAME,
    is_doc_only = false,
    fullname = _("在线书库本地书架"),
}

local function current_ui()
    local ok_fm, FileManager = pcall(require, "apps/filemanager/filemanager")
    if ok_fm and FileManager.instance then
        return FileManager.instance
    end
    local ok_reader, ReaderUI = pcall(require, "apps/reader/readerui")
    if ok_reader and ReaderUI.instance then
        return ReaderUI.instance
    end
end

local function current_bridge_instance()
    local ui = current_ui()
    return ui and ui[PLUGIN_NAME]
end

local function format_last_sync(timestamp)
    timestamp = tonumber(timestamp) or 0
    if timestamp <= 0 then
        return _("从未同步")
    end
    return os.date("%Y-%m-%d %H:%M", timestamp)
end

local function provider_plugin(ui, provider)
    if ui and ui[provider.plugin_name] then
        return ui[provider.plugin_name]
    end
    if PluginLoader and PluginLoader.getPluginInstance then
        local ok, instance = pcall(
            PluginLoader.getPluginInstance, PluginLoader,
            provider.plugin_name
        )
        if ok then
            return instance
        end
    end
end

function ProviderLibraryBridge:init()
    self.settings = Settings:new()
    self.providers = Registry.load(self.path)
    UIPatch.install(PLUGIN_NAME)
    if self.ui.menu then
        self.ui.menu:registerToMainMenu(self)
    end
    self:startScheduler()
end

function ProviderLibraryBridge:rescanProviders()
    self.providers = Registry.load(self.path)
    local available = 0
    for _, provider in ipairs(self.providers) do
        if provider_plugin(self.ui, provider) then
            available = available + 1
        end
    end
    UIManager:show(InfoMessage:new{
        text = string.format(
            _("已扫描到 %d 个来源适配器\n其中 %d 个来源插件当前可用"),
            #self.providers, available
        ),
        timeout = 3,
    })
end

function ProviderLibraryBridge:startScheduler()
    if scheduler_started then
        return
    end
    scheduler_started = true

    local function schedule_next()
        UIManager:scheduleIn(AUTO_CHECK_INTERVAL, function()
            local bridge = current_bridge_instance()
            if bridge then
                bridge:checkAutoSync()
            end
            schedule_next()
        end)
    end
    schedule_next()
end

function ProviderLibraryBridge:checkAutoSync()
    local settings = self.settings
    if not settings:get("auto_sync_enabled", false) then
        return
    end

    local interval = math.max(
        15,
        tonumber(settings:get("auto_sync_interval_minutes", 1440)) or 1440
    )
    local last_attempt = tonumber(settings:get("last_auto_attempt", 0)) or 0
    if os.time() - last_attempt < interval * 60 then
        return
    end
    settings:set("last_auto_attempt", os.time())
    settings:flush()
    self:runSync(true)
end

function ProviderLibraryBridge:runSync(silent)
    if auto_sync_running then
        if not silent then
            UIManager:show(InfoMessage:new{
                text = _("在线书库正在同步，请稍候。"),
                timeout = 2,
            })
        end
        return
    end

    auto_sync_running = true
    local allow_network = NetworkMgr:isConnected()
    local settings = self.settings
    local providers = self.providers
    local ui = self.ui

    if not silent then
        UIManager:show(BottomMessage:new{
            text = _("正在同步在线书库占位书…"),
            timeout = 1,
            show_icon = false,
        })
        UIManager:forceRePaint()
    end

    local ok, report = pcall(function()
        return Sync.run{
            ui = ui,
            plugin_loader = PluginLoader,
            providers = providers,
            settings = settings,
            allow_network = allow_network,
            plugin_path = self.path,
        }
    end)
    auto_sync_running = false

    if not ok then
        logger.err("provider-library-bridge: sync failed:", tostring(report))
        settings:set("last_status", "failed: " .. tostring(report))
        settings:flush()
        if not silent then
            UIManager:show(InfoMessage:new{
                text = _("同步失败：") .. tostring(report),
            })
        end
        return
    end

    settings:set("last_sync", report.finished_at)
    settings:set("last_status", string.format(
        "created=%d updated=%d unchanged=%d failed=%d",
        report.created, report.updated, report.unchanged, report.failed
    ))
    settings:flush()

    if ui.file_chooser and ui.file_chooser.refreshPath then
        ui.file_chooser:refreshPath()
    end
    UIManager:broadcastEvent(Event:new("BookMetadataChanged"))

    if not silent or report.failed > 0 then
        UIManager:show(BottomMessage:new{
            text = string.format(
                _("同步完成\n新建 %d，更新 %d，未变化 %d，失败 %d"),
                report.created, report.updated, report.unchanged, report.failed
            ),
            timeout = 4,
            show_icon = false,
        })
    end
end

function ProviderLibraryBridge:confirmClearPlaceholders()
    local dialog
    dialog = ButtonDialog:new{
        title = _("删除本插件创建的全部在线书库占位书？\n只删除带有效占位标记的文件。"),
        buttons = {
            {
                {
                    text = _("取消"),
                    callback = function()
                        UIManager:close(dialog)
                    end,
                },
                {
                    text = _("删除"),
                    callback = function()
                        UIManager:close(dialog)
                        local removed, failed = Sync.clear_placeholders(
                            self.providers, self.settings
                        )
                        if self.ui.file_chooser and self.ui.file_chooser.refreshPath then
                            self.ui.file_chooser:refreshPath()
                        end
                        UIManager:show(InfoMessage:new{
                            text = string.format(
                                _("已删除 %d 个占位书，失败 %d 个"),
                                removed, failed
                            ),
                            timeout = 3,
                        })
                    end,
                },
            },
        },
    }
    UIManager:show(dialog)
end

function ProviderLibraryBridge:toggleAutoSync()
    local enabled = not self.settings:get("auto_sync_enabled", false)
    self.settings:set("auto_sync_enabled", enabled)
    self.settings:flush()
    UIManager:show(InfoMessage:new{
        text = enabled and _("已启用定时同步。") or _("已关闭定时同步。"),
        timeout = 2,
    })
    if enabled then
        self:checkAutoSync()
    end
end

function ProviderLibraryBridge:setAutoSyncInterval(minutes)
    self.settings:set("auto_sync_interval_minutes", minutes)
    self.settings:flush()
    UIManager:show(InfoMessage:new{
        text = string.format(_("同步间隔已设为 %d 分钟"), minutes),
        timeout = 2,
    })
end

function ProviderLibraryBridge:getSyncScopeLabel()
    local scope = self.settings:get("sync_scope", "known_shelf")
    return scope == "cached_only" and _("仅已缓存") or _("已知书架（含未缓存）")
end

function ProviderLibraryBridge:setSyncScope(scope)
    if scope ~= "cached_only" then
        scope = "known_shelf"
    end
    self.settings:set("sync_scope", scope)
    self.settings:flush()
    UIManager:show(InfoMessage:new{
        text = string.format(
            _("同步范围已设为“%s”，立即同步后生效。"),
            self:getSyncScopeLabel()
        ),
        timeout = 3,
    })
end

function ProviderLibraryBridge:getSyncScopeItems()
    local options = {
        {
            value = "known_shelf",
            label = _("已知书架（含未缓存）"),
        },
        {
            value = "cached_only",
            label = _("仅已缓存"),
        },
    }
    local items = {}
    for _, option in ipairs(options) do
        items[#items + 1] = {
            text = option.label,
            checked_func = function()
                return self.settings:get("sync_scope", "known_shelf")
                    == option.value
            end,
            callback = function()
                self:setSyncScope(option.value)
            end,
            keep_menu_open = true,
        }
    end
    return items
end

function ProviderLibraryBridge:providerIsAvailable(provider)
    return provider_plugin(self.ui, provider) ~= nil
end

function ProviderLibraryBridge:setProviderEnabled(provider, enabled)
    self.settings:set_provider_enabled(provider.id, enabled)
    self.settings:flush()
    UIManager:show(InfoMessage:new{
        text = string.format(
            enabled and _("已启用来源：%s") or _("已停用来源：%s"),
            provider.label
        ),
        timeout = 2,
    })
end

function ProviderLibraryBridge:getProviderSelectionSummary()
    local available = 0
    local enabled = 0
    for _, provider in ipairs(self.providers or {}) do
        if self:providerIsAvailable(provider) then
            available = available + 1
            if self.settings:is_provider_enabled(provider.id) then
                enabled = enabled + 1
            end
        end
    end
    return enabled, available
end

function ProviderLibraryBridge:getProviderItems()
    local items = {
        {
            text = _("重新扫描来源插件"),
            callback = function()
                self:rescanProviders()
            end,
            keep_menu_open = true,
            separator = true,
        },
    }
    for _, provider in ipairs(self.providers or {}) do
        local selected_provider = provider
        local available = self:providerIsAvailable(selected_provider)
        items[#items + 1] = {
            text_func = function()
                local label = selected_provider.label
                if not available then
                    label = label .. _("（插件未启用）")
                end
                return label
            end,
            checked_func = function()
                return available
                    and self.settings:is_provider_enabled(selected_provider.id)
            end,
            enabled_func = function()
                return available
            end,
            callback = function()
                local enabled = self.settings:is_provider_enabled(
                    selected_provider.id
                )
                self:setProviderEnabled(selected_provider, not enabled)
            end,
            keep_menu_open = true,
        }
    end
    return items
end

function ProviderLibraryBridge:getAutoSyncIntervalItems()
    local presets = {
        { 15, _("15 分钟") },
        { 60, _("1 小时") },
        { 360, _("6 小时") },
        { 1440, _("24 小时") },
    }
    local items = {}
    for _, preset in ipairs(presets) do
        local minutes, label = preset[1], preset[2]
        items[#items + 1] = {
            text = label,
            checked_func = function()
                return (tonumber(self.settings:get("auto_sync_interval_minutes", 1440)) or 1440)
                    == minutes
            end,
            callback = function()
                self:setAutoSyncInterval(minutes)
            end,
            keep_menu_open = true,
        }
    end
    return items
end

function ProviderLibraryBridge:addToMainMenu(menu_items)
    if self.ui.document then
        return
    end

    menu_items.provider_library_menu = {
        text = _("在线书库本地书架"),
        sorting_hint = "tools",
        sub_item_table_func = function()
            return self:getSettingsMenuItems()
        end,
    }
end

function ProviderLibraryBridge:getSettingsMenuItems()
    local items = {}
    items[#items + 1] = {
        text = _("立即同步"),
        callback = function()
            self:runSync(false)
        end,
    }
    items[#items + 1] = {
        text_func = function()
            return string.format(_("同步范围：%s"), self:getSyncScopeLabel())
        end,
        sub_item_table_func = function()
            return self:getSyncScopeItems()
        end,
    }
    items[#items + 1] = {
        text_func = function()
            local enabled, available = self:getProviderSelectionSummary()
            return string.format(
                _("同步来源：%d / %d 个可用"),
                enabled, available
            )
        end,
        sub_item_table_func = function()
            return self:getProviderItems()
        end,
    }
    items[#items + 1] = {
        text = _("定时同步"),
        checked_func = function()
            return self.settings:get("auto_sync_enabled", false) == true
        end,
        callback = function()
            self:toggleAutoSync()
        end,
        keep_menu_open = true,
    }
    items[#items + 1] = {
        text = _("同步间隔"),
        sub_item_table_func = function()
            return self:getAutoSyncIntervalItems()
        end,
    }
    items[#items + 1] = {
        text = string.format(
            _("上次同步：%s"),
            format_last_sync(self.settings:get("last_sync", 0))
        ),
        enabled = false,
    }
    items[#items + 1] = {
        text = _("清除在线书库占位书"),
        callback = function()
            self:confirmClearPlaceholders()
        end,
    }
    return items
end

function ProviderLibraryBridge:onNetworkConnected()
    self:checkAutoSync()
end

function ProviderLibraryBridge:onResume()
    self:checkAutoSync()
end

function ProviderLibraryBridge:onReaderReady()
    if not (self.ui and self.ui.doc_settings and self.ui.document) then
        return
    end

    local marker = self.ui.doc_settings:readSetting("provider_library_placeholder")
    if type(marker) ~= "table" or marker.version ~= 1 then
        return
    end
    if self._opening_placeholder then
        return
    end
    self._opening_placeholder = true
    marker.last_opened_at = os.time()
    self.ui.doc_settings:saveSetting("provider_library_placeholder", marker)
    self.ui.doc_settings:flush()

    local placeholder_path = self.ui.document.file
    local provider = Registry.by_id(self.providers, marker.provider_id)
    UIManager:nextTick(function()
        if not provider then
            self._opening_placeholder = nil
            UIManager:show(InfoMessage:new{
                text = _("未知的在线书库 Provider，无法打开占位书。"),
            })
            return
        end

        local provider_plugin = self.ui[provider.plugin_name]
        local prepared_book = marker.book or {}
        if type(provider.prepare) == "function" then
            UIManager:show(BottomMessage:new{
                text = _("正在获取最新阅读进度…"),
                timeout = 1,
                show_icon = false,
            })
            UIManager:forceRePaint()
            local prepared, result = pcall(
                provider.prepare, provider, provider_plugin, prepared_book
            )
            if prepared and type(result) == "table" then
                prepared_book = result
                marker.progress_percent = U.progress_percent(
                    prepared_book.progress
                )
                marker.last_read_title = U.trim(
                    prepared_book.item_show_title
                        or prepared_book.last_chapter_title
                        or marker.last_read_title
                )
                local progress_percent = U.progress_percent(
                    prepared_book.progress
                )
                if progress_percent ~= nil then
                    self.ui.doc_settings:saveSetting(
                        "percent_finished", progress_percent / 100
                    )
                end
                self.ui.doc_settings:saveSetting(
                    "provider_library_placeholder", marker
                )
                self.ui.doc_settings:flush()
            end
        end
        local opened, err = provider:open(
            provider_plugin, prepared_book
        )
        self._opening_placeholder = nil
        if opened == false then
            UIManager:show(InfoMessage:new{
                text = string.format(
                    _("无法打开 %s 占位书：\n%s"),
                    provider.label,
                    tostring(err or _("来源插件不可用"))
                ),
            })
        end
    end)
end

return ProviderLibraryBridge

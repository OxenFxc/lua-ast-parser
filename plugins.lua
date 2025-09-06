-- 插件系统
-- 支持扩展语法和功能

local M = {}

-- 已注册的插件列表
M.registered_plugins = {}

-- 插件接口
M.PluginInterface = {
    -- 插件基本信息
    name = "plugin_name",
    version = "1.0.0",
    description = "Plugin description",

    -- 初始化方法（插件加载时调用）
    init = function(config) end,

    -- 扩展词法器
    extend_lexer = function(lexer) end,

    -- 扩展语法器
    extend_parser = function(parser) end,

    -- 扩展AST节点类型
    extend_ast_nodes = function(ast) end,

    -- 扩展打印器
    extend_printer = function(printer) end,

    -- 扩展解释器
    extend_interpreter = function(interpreter) end,

    -- 扩展内置函数
    extend_builtins = function(builtins) end,

    -- 清理方法（插件卸载时调用）
    cleanup = function() end
}

-- 注册插件
function M.register(plugin_def)
    if not plugin_def.name then
        error("Plugin must have a name")
    end

    if M.registered_plugins[plugin_def.name] then
        error("Plugin '" .. plugin_def.name .. "' is already registered")
    end

    -- 创建插件实例
    local plugin = setmetatable(plugin_def, {__index = M.PluginInterface})

    -- 验证插件接口
    M.validate_plugin(plugin)

    -- 注册插件
    M.registered_plugins[plugin.name] = plugin

    return plugin
end

-- 验证插件接口
function M.validate_plugin(plugin)
    -- 检查必需的方法
    local required_methods = {"init"}
    for _, method in ipairs(required_methods) do
        if type(plugin[method]) ~= "function" then
            error("Plugin '" .. plugin.name .. "' must implement method: " .. method)
        end
    end

    -- 检查版本格式
    if plugin.version and not plugin.version:match("^%d+%.%d+%.%d+$") then
        error("Plugin '" .. plugin.name .. "' has invalid version format: " .. plugin.version)
    end
end

-- 获取已注册的插件
function M.get_registered_plugins()
    return M.registered_plugins
end

-- 获取指定插件
function M.get_plugin(name)
    return M.registered_plugins[name]
end

-- 卸载插件
function M.unregister(name)
    local plugin = M.registered_plugins[name]
    if plugin then
        -- 调用清理方法
        if plugin.cleanup then
            pcall(plugin.cleanup)
        end

        M.registered_plugins[name] = nil
        return true
    end
    return false
end

-- 加载插件（初始化）
function M.load_plugin(name, config)
    local plugin = M.get_plugin(name)
    if not plugin then
        error("Plugin '" .. name .. "' not found")
    end

    -- 调用初始化方法
    if plugin.init then
        local success, err = pcall(plugin.init, config or {})
        if not success then
            error("Failed to initialize plugin '" .. name .. "': " .. err)
        end
    end

    return plugin
end

-- 批量加载插件
function M.load_plugins(plugin_list, config)
    config = config or {}

    for _, plugin_name in ipairs(plugin_list) do
        local plugin_config = config[plugin_name] or {}
        M.load_plugin(plugin_name, plugin_config)
    end
end

-- 插件管理器类
local PluginManager = {}
PluginManager.__index = PluginManager

-- 创建插件管理器
function M.create_manager()
    local self = setmetatable({}, PluginManager)
    self.loaded_plugins = {}
    self.config = {}
    return self
end

-- 管理器：注册插件
function PluginManager:register(plugin_def)
    M.register(plugin_def)
end

-- 管理器：加载插件
function PluginManager:load(name, config)
    local plugin = M.load_plugin(name, config)
    self.loaded_plugins[name] = plugin
    self.config[name] = config or {}
    return plugin
end

-- 管理器：卸载插件
function PluginManager:unload(name)
    if self.loaded_plugins[name] then
        M.unregister(name)
        self.loaded_plugins[name] = nil
        self.config[name] = nil
        return true
    end
    return false
end

-- 管理器：获取已加载的插件
function PluginManager:get_loaded_plugins()
    return self.loaded_plugins
end

-- 管理器：重新加载插件
function PluginManager:reload(name)
    local config = self.config[name]
    self:unload(name)
    return self:load(name, config)
end

-- 导出插件管理器
M.PluginManager = PluginManager

return M

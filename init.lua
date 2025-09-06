-- Lua Parser - 主入口
-- 纯 Lua 实现的 Lua 解析器，支持 Lua→AST 和 AST→Lua 转换

local M = {}

-- 版本信息
M.VERSION = "0.1.0"
M.API_VERSION = "1.0"

-- 预加载工具模块
local position = require("lua.utils.position")
local diagnostics = require("lua.utils.diagnostics")
local string_ext = require("lua.utils.string_ext")
local table_ext = require("lua.utils.table_ext")

-- 导出工具模块
M.utils = {
    position = position,
    diagnostics = diagnostics,
    string_ext = string_ext,
    table_ext = table_ext
}

-- 预加载核心模块
local lexer = require("lua.lexer")
local parser = require("lua.parser")
local printer = require("lua.printer")
local interpreter_module

-- 解析 Lua 源码为 AST
-- @param source string Lua 源代码
-- @param options table 可选配置
-- @return boolean, table 成功返回 true 和 AST，失败返回 false 和诊断信息
function M.parse_lua(source, options)
    options = options or {}
    
    -- 延迟加载解析器
    if not parser then
        parser = require("lua.parser")
    end
    
    return parser.parse(source, options)
end

-- 将 AST 打印为 Lua 源码
-- @param ast table AST 根节点
-- @param options table 可选配置
-- @return boolean, table 成功返回 true 和 {code, map}，失败返回 false 和诊断信息
function M.print_lua(ast, options)
    options = options or {}
    
    -- 延迟加载打印器
    if not printer then
        printer = require("lua.printer")
    end
    
    return printer.print(ast, options)
end

-- 解释执行 AST
-- @param ast table AST 根节点
-- @param options table 可选配置
-- @return boolean, any 成功返回 true 和执行结果，失败返回 false 和诊断信息
function M.interpret_lua(ast, options)
    options = options or {}
    
    -- 延迟加载解释器
    if not interpreter_module then
        interpreter_module = require("lua.interpreter")
    end

    return interpreter_module.interpret(ast, options)
end

-- 创建新的解析器实例（支持独立配置）
-- @param config table 解析器配置
-- @return table 解析器实例
function M.create_parser(config)
    local Parser = require("lua.parser")
    return Parser:new(config)
end

-- 插件系统
local plugins = require("lua.plugins")

-- 注册插件
-- @param plugin table 插件定义
function M.register_plugin(plugin)
    return plugins.register(plugin)
end

-- 获取插件
function M.get_plugin(name)
    return plugins.get_plugin(name)
end

-- 加载插件
function M.load_plugin(name, config)
    return plugins.load_plugin(name, config)
end

-- 卸载插件
function M.unload_plugin(name)
    return plugins.unregister(name)
end

-- 创建插件管理器
function M.create_plugin_manager()
    return plugins.create_manager()
end

-- 获取已注册的插件列表
function M.get_registered_plugins()
    return plugins.get_registered_plugins()
end

return M

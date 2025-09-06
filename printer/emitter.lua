-- 源码发射器：负责字符串输出与缩进管理

local M = {}

-- 发射器类
local Emitter = {}
Emitter.__index = Emitter

-- 创建新的发射器
function M.create(options)
    local self = setmetatable({}, Emitter)
    self.options = options or {}
    self.buffer = {}
    self.indent_level = 0
    self.indent_string = self.options.indent or "  "
    self.line_length = 0
    self.max_line_length = self.options.max_line_length or 80

    return self
end

-- 输出字符串
function Emitter:emit(str)
    if not str or str == "" then
        return
    end

    table.insert(self.buffer, str)
    self.line_length = self.line_length + #str
end

-- 输出带缩进的字符串
function Emitter:emit_indented(str)
    self:emit_indent()
    self:emit(str)
end

-- 输出缩进
function Emitter:emit_indent()
    if self.indent_level > 0 then
        local indent = string.rep(self.indent_string, self.indent_level)
        self:emit(indent)
    end
end

-- 输出换行符
function Emitter:emit_newline()
    self:emit("\n")
    self.line_length = 0
end

-- 输出分号
function Emitter:emit_semicolon()
    if self.options.semicolons ~= "omit" then
        self:emit(";")
    end
end

-- 增加缩进级别
function Emitter:increase_indent()
    self.indent_level = self.indent_level + 1
end

-- 减少缩进级别
function Emitter:decrease_indent()
    self.indent_level = math.max(0, self.indent_level - 1)
end

-- 获取当前输出
function Emitter:get_output()
    return table.concat(self.buffer)
end

-- 清空缓冲区
function Emitter:clear()
    self.buffer = {}
    self.line_length = 0
end

-- 检查是否需要换行（基于行长度限制）
function Emitter:should_break_line()
    return self.line_length >= self.max_line_length
end

-- 输出多个项目，用指定分隔符连接
function Emitter:emit_list(items, separator, break_lines)
    if not items or #items == 0 then
        return
    end

    separator = separator or ", "
    break_lines = break_lines or false

    for i, item in ipairs(items) do
        self:emit(item)

        if i < #items then
            self:emit(separator)
            if break_lines then
                self:emit_newline()
            end
        end
    end
end

-- 输出注释
function Emitter:emit_comment(comment, inline)
    if not comment or comment == "" then
        return
    end

    if inline then
        self:emit(" -- " .. comment)
    else
        self:emit_indented("-- " .. comment)
        self:emit_newline()
    end
end

-- 输出块注释
function Emitter:emit_block_comment(comment)
    if not comment or comment == "" then
        return
    end

    self:emit_indented("--[[")
    self:emit_newline()

    -- 增加缩进
    self:increase_indent()

    -- 分行输出注释内容
    local lines = {}
    for line in comment:gmatch("[^\n]*") do
        table.insert(lines, line)
    end

    for _, line in ipairs(lines) do
        if line ~= "" then
            self:emit_indented(line)
        end
        self:emit_newline()
    end

    -- 减少缩进
    self:decrease_indent()

    self:emit_indented("--]]")
    self:emit_newline()
end

-- 格式化字符串字面量
function Emitter:format_string(str)
    if not str then
        return '""'
    end

    -- 选择合适的引号
    local use_double = str:find("'") and not str:find('"')
    local quote = use_double and '"' or "'"

    -- 转义字符串
    local string_ext = require("lua.utils.string_ext")
    local escaped = string_ext.escape_string(str)

    return quote .. escaped .. quote
end

-- 格式化数字字面量
function Emitter:format_number(num)
    if type(num) == "number" then
        -- 保持原始格式，如果是整数则不添加小数点
        local str = tostring(num)
        if str:find("%.") then
            return str
        else
            return str .. ".0"
        end
    end
    return tostring(num)
end

-- 格式化标识符
function Emitter:format_identifier(name)
    if not name or type(name) ~= "string" then
        return "_"
    end

    -- 检查是否需要引号（包含特殊字符或与关键字冲突）
    local keywords = require("lua.lexer.keywords")
    if keywords.is_reserved(name) or not string.match(name, "^[a-zA-Z_][a-zA-Z0-9_]*$") then
        return string.format("[%q]", name)
    end

    return name
end

-- 创建临时发射器（用于计算子表达式的长度）
function M.create_temp_emitter(options)
    local emitter = M.create(options)
    emitter.buffer = {}  -- 临时缓冲区
    return emitter
end

-- 获取发射器的行长度
function Emitter:get_line_length()
    return self.line_length
end

-- 设置行长度限制
function Emitter:set_max_line_length(length)
    self.max_line_length = length or 80
end

-- 重置行长度计数器
function Emitter:reset_line_length()
    self.line_length = 0
end

return M

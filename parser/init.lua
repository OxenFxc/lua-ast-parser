-- 语法器主入口与递归下降解析器

local M = {}

-- 导入依赖
local lexer = require("lua.lexer")
local ast = require("lua.ast")
local diagnostics = require("lua.utils.diagnostics")
local expressions = require("lua.parser.expressions")
local statements = require("lua.parser.statements")

-- 语法器类
local Parser = {}
Parser.__index = Parser

-- 创建新的语法器
function M.create(source, options)
    options = options or {}

    local self = setmetatable({}, Parser)

    -- 初始化词法器
    self.lexer = lexer.create(source, {
        skip_comments = options.skip_comments ~= false,
        skip_newlines = options.skip_newlines ~= false
    })

    -- 获取 token 流
    local tokens, lexer_diagnostics = self.lexer:tokenize()
    self.tokens = tokens
    self.diagnostics = diagnostics.create_collector()

    -- 添加词法器诊断信息
    for _, diag in ipairs(lexer_diagnostics) do
        self.diagnostics:add(diag)
    end

    -- 初始化解析状态
    self.current = 1  -- 当前 token 索引
    self.last_location = nil

    -- 创建子解析器
    self.expression_parser = expressions.create(self)
    self.statement_parser = statements.create(self)

    return self
end

-- 主要解析入口
function M.parse(source, options)
    local parser = M.create(source, options)

    -- 解析程序
    local program = parser:parse_program()

    -- 检查是否有错误
    if parser.diagnostics:has_errors() then
        return false, parser.diagnostics:get_diagnostics()
    end

    return true, program
end

-- 解析完整程序
function Parser:parse_program()
    local statements = {}
    local start_loc = nil

    -- 解析所有语句
    while not self:is_at_end() do
        -- 跳过分号和换行符
        while self:check("SEMICOLON") or self:check("NEWLINE") do
            self:advance()
        end

        if self:is_at_end() then
            break
        end

        local stmt = self.statement_parser:parse_statement()
        if stmt then
            if not start_loc then
                start_loc = stmt.loc.start
            end
            table.insert(statements, stmt)
        end

        -- 跳过分号（可选）
        if self:check("SEMICOLON") then
            self:advance()
        end
    end

    if not start_loc then
        start_loc = {line = 1, column = 1}
    end

    local end_loc = self:previous() and self:previous().loc["end"] or start_loc
    local range = {0, self:position_to_offset(end_loc)}

    return ast.create_program(statements, {start = start_loc, ["end"] = end_loc}, range)
end

-- Token 操作方法

-- 前进一个 token
function Parser:advance()
    if not self:is_at_end() then
        self.current = self.current + 1
    end
end

-- 查看当前 token
function Parser:peek(offset)
    offset = offset or 0
    local index = self.current + offset
    if index > #self.tokens then
        return nil
    end
    return self.tokens[index]
end

-- 获取上一个 token
function Parser:previous()
    if self.current > 1 then
        return self.tokens[self.current - 1]
    end
    return nil
end

-- 检查当前 token 类型
function Parser:check(type)
    local token = self:peek()
    return token and token.type == type
end

-- 检查当前 token 值
function Parser:check_value(value)
    local token = self:peek()
    return token and token.value == value
end

-- 匹配并消耗 token
function Parser:match(type)
    if self:check(type) then
        self:advance()
        return true
    end
    return false
end

-- 期望特定类型的 token
function Parser:expect(type)
    if self:check(type) then
        self:advance()
        return true
    end

    local token = self:peek()
    local message = string.format("Expected %s", type)
    if token then
        message = message .. string.format(", got %s", token.type)
    end

    self:add_error(message, token and token.loc or self.last_location or {start={line=1,column=1}, ["end"]={line=1,column=1}})
    return false
end

-- 检查是否到达文件末尾
function Parser:is_at_end()
    return self.current > #self.tokens or self:peek().type == "EOF"
end

-- 位置转换辅助方法

-- 从位置创建偏移
function Parser:position_to_offset(position)
    if not position then
        return 0
    end

    -- 简单实现：假设每个字符占1字节
    -- 在实际实现中，这里应该使用词法器的位置跟踪
    return (position.line - 1) * 80 + position.column  -- 估算值
end

-- 创建位置范围
function Parser:create_span(start_pos, end_pos)
    return {
        loc = {
            start = start_pos,
            ["end"] = end_pos
        },
        range = {
            self:position_to_offset(start_pos),
            self:position_to_offset(end_pos)
        }
    }
end

-- 错误处理

-- 添加错误
function Parser:add_error(message, loc)
    self.diagnostics:add_error(message, loc, "parser")
end

-- 添加警告
function Parser:add_warning(message, loc)
    self.diagnostics:add_warning(message, loc, "parser")
end

-- 获取所有诊断信息
function Parser:get_diagnostics()
    return self.diagnostics:get_diagnostics()
end

-- 调试辅助方法

-- 打印当前解析状态
function Parser:debug_state()
    local token = self:peek()
    print(string.format("Parser state: token %d/%d, type=%s, value=%s",
        self.current, #self.tokens,
        token and token.type or "nil",
        token and token.value or "nil"))
end

-- 打印剩余的 token
function Parser:debug_remaining_tokens(limit)
    limit = limit or 10
    print("Remaining tokens:")
    for i = 0, math.min(limit - 1, #self.tokens - self.current) do
        local token = self.tokens[self.current + i]
        print(string.format("  %d: %s %s", i+1, token.type, token.value))
    end
end

return M

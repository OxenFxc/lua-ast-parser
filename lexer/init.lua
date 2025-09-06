-- 词法器主入口与状态机驱动

local M = {}

-- 导入依赖
local token = require("lua.lexer.token")
local keywords = require("lua.lexer.keywords")
local scanner = require("lua.lexer.scanner")
local diagnostics = require("lua.utils.diagnostics")
local position = require("lua.utils.position")

-- 词法器类
local Lexer = {}
Lexer.__index = Lexer

-- 创建新的词法器
function M.create(source, options)
    options = options or {}
    
    local self = setmetatable({}, Lexer)
    self.source = source
    self.scanner = scanner.create(source)
    self.diagnostics = diagnostics.create_collector()
    self.tokens = {}
    self.current_token = nil
    self.peek_token = nil
    
    -- 配置选项
    self.skip_comments = options.skip_comments ~= false
    self.skip_newlines = options.skip_newlines ~= false
    
    return self
end

-- 执行词法分析
function Lexer:tokenize()
    while not self.scanner:is_at_end() do
        local token = self:scan_token()
        if token then
            table.insert(self.tokens, token)
        end
    end
    
    -- 添加 EOF Token
    local eof_loc = {
        start = self.scanner:get_location(),
        ["end"] = self.scanner:get_location()
    }
    local eof_token = token.create_eof(eof_loc, {self.scanner.position, self.scanner.position})
    table.insert(self.tokens, eof_token)
    
    return self.tokens, self.diagnostics:get_diagnostics()
end

-- 扫描单个 Token
function Lexer:scan_token()
    -- 跳过空白字符
    self:skip_whitespace()
    
    if self.scanner:is_at_end() then
        return nil
    end
    
    local mark = self.scanner:mark_start()
    local char = self.scanner:peek()
    
    -- 标识符或关键字
    if self:is_identifier_start(char) then
        return self:scan_identifier(mark)
    end
    
    -- 数字字面量
    if char >= "0" and char <= "9" then
        return self:scan_number(mark)
    end
    
    -- 字符串字面量
    if char == "\"" or char == "\'" then
        return self:scan_string(mark)
    end
    
    -- 长字符串字面量或左方括号
    if char == "[" then
        -- 检查是否为长字符串（[[...]]）
        if self.scanner:peek(1) == "[" then
            return self:scan_long_string(mark)
        else
            -- 普通的左方括号
            self.scanner:advance()
            local span = self.scanner:create_span(mark)
            return token.create(token.TYPE.LEFT_BRACKET, "[", span.loc, span.range)
        end
    end
    
    -- 注释
    if char == "-" and self.scanner:peek(1) == "-" then
        return self:scan_comment(mark)
    end
    
    -- 运算符和分隔符
    local operator_token = self:scan_operator_or_punctuator(mark)
    if operator_token then
        return operator_token
    end
    
    -- 换行符
    if char == "\n" or char == "\r" then
        return self:scan_newline(mark)
    end
    
    -- 未知字符
    self.scanner:advance()
    local span = self.scanner:create_span(mark)
    self.diagnostics:add_error(
        string.format("unexpected character: %s", char),
        span.loc,
        "lexer"
    )
    
    return nil
end

-- 跳过空白字符
function Lexer:skip_whitespace()
    while not self.scanner:is_at_end() do
        local char = self.scanner:peek()
        if char == " " or char == "\t" then
            self.scanner:advance()
        else
            break
        end
    end
end

-- 检查是否为标识符开始字符
function Lexer:is_identifier_start(char)
    local string_ext = require("lua.utils.string_ext")
    return string_ext.is_ident_start(char)
end

-- 扫描标识符或关键字
function Lexer:scan_identifier(mark)
    local ident = self.scanner:read_identifier()
    local span = self.scanner:create_span(mark)
    
    -- 检查是否为关键字
    local token_type = keywords.get_keyword_type(ident)
    if token_type then
        -- 关键字
        local tok = token.create(token_type, ident, span.loc, span.range)
        return tok
    else
        -- 普通标识符
        local tok = token.create(token.TYPE.IDENTIFIER, ident, span.loc, span.range)
        return tok
    end
end

-- 扫描数字字面量
function Lexer:scan_number(mark)
    local num_str = self.scanner:read_number()
    local span = self.scanner:create_span(mark)
    
    -- 验证数字格式
    local num_value = tonumber(num_str)
    if not num_value then
        self.diagnostics:add_error(
            string.format("invalid number: %s", num_str),
            span.loc,
            "lexer"
        )
        return nil
    end
    
    local tok = token.create(token.TYPE.NUMBER, num_str, span.loc, span.range)
    return tok
end

-- 扫描字符串字面量
function Lexer:scan_string(mark)
    local quote = self.scanner:peek()
    local str_value, err = self.scanner:read_string(quote)
    
    if not str_value then
        local span = self.scanner:create_span(mark)
        self.diagnostics:add_error(
            string.format("invalid string: %s", err or "unterminated string"),
            span.loc,
            "lexer"
        )
        return nil
    end
    
    local span = self.scanner:create_span(mark)
    local tok = token.create(token.TYPE.STRING, str_value, span.loc, span.range)
    return tok
end

-- 扫描长字符串字面量
function Lexer:scan_long_string(mark)
    local str_value, err = self.scanner:read_long_string()
    
    if not str_value then
        local span = self.scanner:create_span(mark)
        self.diagnostics:add_error(
            string.format("invalid long string: %s", err),
            span.loc,
            "lexer"
        )
        return nil
    end
    
    local span = self.scanner:create_span(mark)
    local tok = token.create(token.TYPE.STRING, str_value, span.loc, span.range)
    return tok
end

-- 扫描注释
function Lexer:scan_comment(mark)
    -- 跳过 --
    self.scanner:advance(2)
    
    -- 检查是否为长注释
    if self.scanner:peek() == "[" then
        return self:scan_long_comment(mark)
    else
        return self:scan_line_comment(mark)
    end
end

-- 扫描行注释
function Lexer:scan_line_comment(mark)
    local comment_text = ""
    
    while not self.scanner:is_at_end() do
        local char = self.scanner:peek()
        if char == "\n" or char == "\r" then
            break
        end
        comment_text = comment_text .. char
        self.scanner:advance()
    end
    
    local span = self.scanner:create_span(mark)
    
    if not self.skip_comments then
        local tok = token.create_comment(comment_text, span.loc, span.range)
        return tok
    end
    
    return nil
end

-- 扫描长注释
function Lexer:scan_long_comment(mark)
    -- 跳过 [
    self.scanner:advance()
    
    local equals_count = 0
    while self.scanner:peek() == "=" do
        equals_count = equals_count + 1
        self.scanner:advance()
    end
    
    -- 跳过 [
    if self.scanner:peek() ~= "[" then
        local span = self.scanner:create_span(mark)
        self.diagnostics:add_error("invalid long comment delimiter", span.loc, "lexer")
        return nil
    end
    self.scanner:advance()
    
    local comment_text = ""
    local end_marker = "]" .. string.rep("=", equals_count) .. "]"
    
    while not self.scanner:is_at_end() do
        if self.scanner:match(end_marker) then
            break
        end
        
        comment_text = comment_text .. self.scanner:peek()
        self.scanner:advance()
    end
    
    local span = self.scanner:create_span(mark)
    
    if not self.skip_comments then
        local tok = token.create_comment(comment_text, span.loc, span.range)
        return tok
    end
    
    return nil
end

-- 扫描运算符或分隔符
function Lexer:scan_operator_or_punctuator(mark)
    local char = self.scanner:peek()
    
    -- 多字符运算符（需要前瞻）
    if char == "=" then
        if self.scanner:peek(1) == "=" then
            self.scanner:advance(2)
            local span = self.scanner:create_span(mark)
            return token.create(token.TYPE.EQUAL_EQUAL, "==", span.loc, span.range)
        else
            self.scanner:advance()
            local span = self.scanner:create_span(mark)
            return token.create(token.TYPE.EQUAL, "=", span.loc, span.range)
        end
    elseif char == "~" then
        if self.scanner:peek(1) == "=" then
            self.scanner:advance(2)
            local span = self.scanner:create_span(mark)
            return token.create(token.TYPE.TILDE_EQUAL, "~=", span.loc, span.range)
        else
            -- ~ 不是有效的单字符运算符
            return nil
        end
    elseif char == "<" then
        if self.scanner:peek(1) == "=" then
            self.scanner:advance(2)
            local span = self.scanner:create_span(mark)
            return token.create(token.TYPE.LESS_EQUAL, "<=", span.loc, span.range)
        else
            self.scanner:advance()
            local span = self.scanner:create_span(mark)
            return token.create(token.TYPE.LESS, "<", span.loc, span.range)
        end
    elseif char == ">" then
        if self.scanner:peek(1) == "=" then
            self.scanner:advance(2)
            local span = self.scanner:create_span(mark)
            return token.create(token.TYPE.GREATER_EQUAL, ">=", span.loc, span.range)
        else
            self.scanner:advance()
            local span = self.scanner:create_span(mark)
            return token.create(token.TYPE.GREATER, ">", span.loc, span.range)
        end
    elseif char == "/" then
        if self.scanner:peek(1) == "/" then
            self.scanner:advance(2)
            local span = self.scanner:create_span(mark)
            return token.create(token.TYPE.FLOOR_DIV, "//", span.loc, span.range)
        else
            self.scanner:advance()
            local span = self.scanner:create_span(mark)
            return token.create(token.TYPE.SLASH, "/", span.loc, span.range)
        end
    elseif char == ":" then
        if self.scanner:peek(1) == ":" then
            self.scanner:advance(2)
            local span = self.scanner:create_span(mark)
            return token.create(token.TYPE.COLON_COLON, "::", span.loc, span.range)
        else
            self.scanner:advance()
            local span = self.scanner:create_span(mark)
            return token.create(token.TYPE.COLON, ":", span.loc, span.range)
        end
    elseif char == "." then
        if self.scanner:peek(1) == "." then
            if self.scanner:peek(2) == "." then
                self.scanner:advance(3)
                local span = self.scanner:create_span(mark)
                return token.create(token.TYPE.DOT_DOT_DOT, "...", span.loc, span.range)
            else
                self.scanner:advance(2)
                local span = self.scanner:create_span(mark)
                return token.create(token.TYPE.DOT_DOT, "..", span.loc, span.range)
            end
        else
            self.scanner:advance()
            local span = self.scanner:create_span(mark)
            return token.create(token.TYPE.DOT, ".", span.loc, span.range)
        end
    end
    
    -- 单字符运算符和分隔符
    local single_char_tokens = {
        ["+"] = token.TYPE.PLUS,
        ["-"] = token.TYPE.MINUS,
        ["*"] = token.TYPE.STAR,
        ["/"] = token.TYPE.SLASH,
        ["//"] = token.TYPE.FLOOR_DIV,
        ["%"] = token.TYPE.PERCENT,
        ["^"] = token.TYPE.CARET,
        ["#"] = token.TYPE.HASH,
        ["("] = token.TYPE.LEFT_PAREN,
        [")"] = token.TYPE.RIGHT_PAREN,
        ["{"] = token.TYPE.LEFT_BRACE,
        ["}"] = token.TYPE.RIGHT_BRACE,
        ["["] = token.TYPE.LEFT_BRACKET,
        ["]"] = token.TYPE.RIGHT_BRACKET,
        [","] = token.TYPE.COMMA,
        [";"] = token.TYPE.SEMICOLON,

    }
    
    local token_type = single_char_tokens[char]
    if token_type then
        self.scanner:advance()
        local span = self.scanner:create_span(mark)
        return token.create(token_type, char, span.loc, span.range)
    end
    
    return nil
end

-- 扫描换行符
function Lexer:scan_newline(mark)
    local char = self.scanner:peek()
    if char == "\r" and self.scanner:peek(1) == "\n" then
        self.scanner:advance(2)
    else
        self.scanner:advance()
    end
    
    local span = self.scanner:create_span(mark)
    
    if not self.skip_newlines then
        return token.create_newline(span.loc, span.range)
    end
    
    return nil
end

-- 模块函数：快速词法分析
function M.tokenize(source, options)
    local lexer = M.create(source, options)
    return lexer:tokenize()
end

return M

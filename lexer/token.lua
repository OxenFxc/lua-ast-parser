-- Token 类型定义与构造器

local M = {}

-- Token 类型常量
M.TYPE = {
    -- 字面量
    NUMBER = "NUMBER",
    STRING = "STRING",
    BOOLEAN = "BOOLEAN",
    NIL = "NIL",
    
    -- 标识符
    IDENTIFIER = "IDENTIFIER",
    
    -- 关键字
    IF = "IF",
    THEN = "THEN",
    ELSE = "ELSE",
    ELSEIF = "ELSEIF",
    END = "END",
    WHILE = "WHILE",
    DO = "DO",
    FOR = "FOR",
    IN = "IN",
    REPEAT = "REPEAT",
    UNTIL = "UNTIL",
    FUNCTION = "FUNCTION",
    LOCAL = "LOCAL",
    RETURN = "RETURN",
    BREAK = "BREAK",
    AND = "AND",
    OR = "OR",
    NOT = "NOT",
    
    -- 运算符
    PLUS = "PLUS",           -- +
    MINUS = "MINUS",         -- -
    STAR = "STAR",           -- *
    SLASH = "SLASH",         -- /
    FLOOR_DIV = "FLOOR_DIV", -- //
    PERCENT = "PERCENT",     -- %
    CARET = "CARET",         -- ^
    HASH = "HASH",           -- #
    EQUAL = "EQUAL",         -- =
    EQUAL_EQUAL = "EQUAL_EQUAL",     -- ==
    TILDE_EQUAL = "TILDE_EQUAL",     -- ~=
    LESS = "LESS",           -- <
    LESS_EQUAL = "LESS_EQUAL",       -- <=
    GREATER = "GREATER",     -- >
    GREATER_EQUAL = "GREATER_EQUAL", -- >=
    DOT = "DOT",             -- .
    DOT_DOT = "DOT_DOT",     -- ..
    DOT_DOT_DOT = "DOT_DOT_DOT",     -- ...
    
    -- 分隔符
    LEFT_PAREN = "LEFT_PAREN",       -- (
    RIGHT_PAREN = "RIGHT_PAREN",     -- )
    LEFT_BRACE = "LEFT_BRACE",       -- {
    RIGHT_BRACE = "RIGHT_BRACE",     -- }
    LEFT_BRACKET = "LEFT_BRACKET",   -- [
    RIGHT_BRACKET = "RIGHT_BRACKET", -- ]
    COMMA = "COMMA",         -- ,
    SEMICOLON = "SEMICOLON", -- ;
    COLON = "COLON",         -- :
    COLON_COLON = "COLON_COLON", -- ::
    
    -- 特殊
    EOF = "EOF",
    NEWLINE = "NEWLINE",
    COMMENT = "COMMENT"
}

-- Token 值常量
M.VALUE = {
    TRUE = "true",
    FALSE = "false",
    NIL = "nil"
}

-- 创建 Token
-- @param type string Token 类型
-- @param value string Token 原始值
-- @param loc table 位置信息
-- @param range table 范围信息
function M.create(type, value, loc, range)
    return {
        type = type,
        value = value,
        loc = loc,
        range = range
    }
end

-- 创建 EOF Token
function M.create_eof(loc, range)
    return M.create(M.TYPE.EOF, "", loc, range)
end

-- 创建注释 Token
function M.create_comment(value, loc, range)
    return M.create(M.TYPE.COMMENT, value, loc, range)
end

-- 创建换行 Token
function M.create_newline(loc, range)
    return M.create(M.TYPE.NEWLINE, "\n", loc, range)
end

-- Token 是否为字面量
function M.is_literal(token)
    return token.type == M.TYPE.NUMBER or
           token.type == M.TYPE.STRING or
           token.type == M.TYPE.BOOLEAN or
           token.type == M.TYPE.NIL
end

-- Token 是否为关键字
function M.is_keyword(token)
    local keyword_types = {
        [M.TYPE.IF] = true,
        [M.TYPE.THEN] = true,
        [M.TYPE.ELSE] = true,
        [M.TYPE.ELSEIF] = true,
        [M.TYPE.END] = true,
        [M.TYPE.WHILE] = true,
        [M.TYPE.DO] = true,
        [M.TYPE.FOR] = true,
        [M.TYPE.IN] = true,
        [M.TYPE.REPEAT] = true,
        [M.TYPE.UNTIL] = true,
        [M.TYPE.FUNCTION] = true,
        [M.TYPE.LOCAL] = true,
        [M.TYPE.RETURN] = true,
        [M.TYPE.BREAK] = true,
        [M.TYPE.AND] = true,
        [M.TYPE.OR] = true,
        [M.TYPE.NOT] = true
    }
    return keyword_types[token.type] == true
end

-- Token 是否为运算符
function M.is_operator(token)
    local operator_types = {
        [M.TYPE.PLUS] = true,
        [M.TYPE.MINUS] = true,
        [M.TYPE.STAR] = true,
        [M.TYPE.SLASH] = true,
        [M.TYPE.PERCENT] = true,
        [M.TYPE.CARET] = true,
        [M.TYPE.HASH] = true,
        [M.TYPE.EQUAL] = true,
        [M.TYPE.EQUAL_EQUAL] = true,
        [M.TYPE.TILDE_EQUAL] = true,
        [M.TYPE.LESS] = true,
        [M.TYPE.LESS_EQUAL] = true,
        [M.TYPE.GREATER] = true,
        [M.TYPE.GREATER_EQUAL] = true,
        [M.TYPE.DOT] = true,
        [M.TYPE.DOT_DOT] = true,
        [M.TYPE.DOT_DOT_DOT] = true
    }
    return operator_types[token.type] == true
end

-- Token 是否为分隔符
function M.is_punctuator(token)
    local punctuator_types = {
        [M.TYPE.LEFT_PAREN] = true,
        [M.TYPE.RIGHT_PAREN] = true,
        [M.TYPE.LEFT_BRACE] = true,
        [M.TYPE.RIGHT_BRACE] = true,
        [M.TYPE.LEFT_BRACKET] = true,
        [M.TYPE.RIGHT_BRACKET] = true,
        [M.TYPE.COMMA] = true,
        [M.TYPE.SEMICOLON] = true,
        [M.TYPE.COLON] = true
    }
    return punctuator_types[token.type] == true
end

-- Token 是否为标识符
function M.is_identifier(token)
    return token.type == M.TYPE.IDENTIFIER
end

-- 获取 Token 的字符串表示（用于调试）
function M.to_string(token)
    if token.type == M.TYPE.EOF then
        return "<EOF>"
    elseif token.type == M.TYPE.NEWLINE then
        return "<NEWLINE>"
    elseif token.type == M.TYPE.COMMENT then
        return string.format("<COMMENT:%s>", token.value)
    else
        return string.format("<%s:%s>", token.type, token.value)
    end
end

-- Token 比较（用于测试）
function M.equals(left, right)
    if type(left) ~= "table" or type(right) ~= "table" then
        return false
    end
    
    return left.type == right.type and
           left.value == right.value and
           left.loc.start.line == right.loc.start.line and
           left.loc.start.column == right.loc.start.column and
           left.loc["end"].line == right.loc["end"].line and
           left.loc["end"].column == right.loc["end"].column and
           left.range[1] == right.range[1] and
           left.range[2] == right.range[2]
end

return M

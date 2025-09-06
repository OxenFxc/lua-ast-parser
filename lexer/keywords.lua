-- Lua 关键字表与识别

local M = {}

-- Lua 关键字映射表
M.KEYWORDS = {
    -- 控制流
    ["if"] = "IF",
    ["then"] = "THEN",
    ["else"] = "ELSE",
    ["elseif"] = "ELSEIF",
    ["end"] = "END",
    
    -- 循环
    ["while"] = "WHILE",
    ["do"] = "DO",
    ["for"] = "FOR",
    ["in"] = "IN",
    ["repeat"] = "REPEAT",
    ["until"] = "UNTIL",
    
    -- 函数
    ["function"] = "FUNCTION",
    ["local"] = "LOCAL",
    ["return"] = "RETURN",
    
    -- 其他
    ["break"] = "BREAK",
    ["goto"] = "GOTO",
    ["and"] = "AND",
    ["or"] = "OR",
    ["not"] = "NOT",
    
    -- 字面量
    ["true"] = "BOOLEAN",
    ["false"] = "BOOLEAN",
    ["nil"] = "NIL"
}

-- 关键字值映射（反向查找）
M.KEYWORD_VALUES = {}
for keyword, type in pairs(M.KEYWORDS) do
    if not M.KEYWORD_VALUES[type] then
        M.KEYWORD_VALUES[type] = {}
    end
    table.insert(M.KEYWORD_VALUES[type], keyword)
end

-- 判断字符串是否为关键字
function M.is_keyword(str)
    return M.KEYWORDS[str] ~= nil
end

-- 获取关键字类型
function M.get_keyword_type(str)
    return M.KEYWORDS[str]
end

-- 获取指定类型的所有关键字
function M.get_keywords_by_type(type)
    return M.KEYWORD_VALUES[type] or {}
end

-- 判断字符串是否为保留字（不能作为标识符）
function M.is_reserved(str)
    local token_type = M.KEYWORDS[str]
    return token_type and token_type ~= "BOOLEAN" and token_type ~= "NIL"
end

-- 获取所有关键字列表
function M.get_all_keywords()
    local result = {}
    for keyword in pairs(M.KEYWORDS) do
        table.insert(result, keyword)
    end
    table.sort(result)
    return result
end

-- 获取所有保留字列表
function M.get_reserved_words()
    local result = {}
    for keyword, token_type in pairs(M.KEYWORDS) do
        if token_type ~= "BOOLEAN" and token_type ~= "NIL" then
            table.insert(result, keyword)
        end
    end
    table.sort(result)
    return result
end

return M

-- 字符串处理扩展工具

local M = {}

-- 判断字符是否为空白字符
function M.is_whitespace(char)
    return char == " " or char == "\t" or char == "\n" or char == "\r"
end

-- 判断字符是否为字母
function M.is_alpha(char)
    local byte = string.byte(char)
    return (byte >= 65 and byte <= 90) or  -- A-Z
           (byte >= 97 and byte <= 122)     -- a-z
end

-- 判断字符是否为数字
function M.is_digit(char)
    local byte = string.byte(char)
    return byte >= 48 and byte <= 57  -- 0-9
end

-- 判断字符是否为十六进制数字
function M.is_hex_digit(char)
    local byte = string.byte(char)
    return M.is_digit(char) or
           (byte >= 65 and byte <= 70) or  -- A-F
           (byte >= 97 and byte <= 102)    -- a-f
end

-- 判断字符是否为标识符起始字符
function M.is_ident_start(char)
    return M.is_alpha(char) or char == "_"
end

-- 判断字符是否为标识符字符
function M.is_ident_char(char)
    return M.is_alpha(char) or M.is_digit(char) or char == "_"
end

-- 去除字符串首尾空白
function M.trim(str)
    return string.match(str, "^%s*(.-)%s*$")
end

-- 分割字符串
function M.split(str, delimiter)
    delimiter = delimiter or "%s"
    local result = {}
    local pattern = string.format("([^%s]+)", delimiter)
    
    for match in str:gmatch(pattern) do
        table.insert(result, match)
    end
    
    return result
end

-- 字符串开始匹配
function M.starts_with(str, prefix)
    return string.sub(str, 1, string.len(prefix)) == prefix
end

-- 字符串结束匹配
function M.ends_with(str, suffix)
    return string.sub(str, -string.len(suffix)) == suffix
end

-- 转义 Lua 字符串
function M.escape_string(str)
    local replacements = {
        ["\\"] = "\\\\",
        ["\""] = "\\\"",
        ["\'"] = "\\\'",
        ["\n"] = "\\n",
        ["\r"] = "\\r",
        ["\t"] = "\\t",
        ["\b"] = "\\b",
        ["\f"] = "\\f",
        ["\a"] = "\\a",
        ["\v"] = "\\v"
    }
    
    return string.gsub(str, ".", function(char)
        return replacements[char] or char
    end)
end

-- 反转义 Lua 字符串
function M.unescape_string(str)
    local replacements = {
        ["\\\\"] = "\\",
        ["\\\""] = "\"",
        ["\\\'"] = "\'",
        ["\\n"] = "\n",
        ["\\r"] = "\r",
        ["\\t"] = "\t",
        ["\\b"] = "\b",
        ["\\f"] = "\f",
        ["\\a"] = "\a",
        ["\\v"] = "\v"
    }
    
    -- 处理数字转义序列 \ddd
    str = string.gsub(str, "\\(%d%d?%d?)", function(digits)
        local num = tonumber(digits)
        if num and num <= 255 then
            return string.char(num)
        end
        return "\\" .. digits
    end)

    -- 处理其他转义序列
    for pattern, replacement in pairs(replacements) do
        str = string.gsub(str, pattern, replacement)
    end
    
    return str
end

-- 计算长字符串的等号数量
function M.count_long_string_equals(str)
    local max_equals = 0
    
    -- 查找字符串中已存在的 ]] 或 ]=] 模式
    for equals in string.gmatch(str, "%](%=*)%]") do
        max_equals = math.max(max_equals, string.len(equals))
    end
    
    return max_equals + 1
end

-- 创建长字符串括号
function M.create_long_brackets(level)
    local equals = string.rep("=", level)
    return "[" .. equals .. "[", "]" .. equals .. "]"
end

-- 判断是否需要使用长字符串
function M.needs_long_string(str)
    -- 包含换行或特殊字符时使用长字符串
    return string.find(str, "\n") or string.find(str, "\r") or
           string.find(str, "\\") or string.find(str, "\"") or string.find(str, "\'")
end

-- 格式化为合适的字符串字面量
function M.format_string_literal(str)
    if M.needs_long_string(str) then
        local level = M.count_long_string_equals(str)
        local open, close = M.create_long_brackets(level)
        return open .. str .. close
    else
            -- 优先使用单引号，如果包含单引号则使用双引号
    if string.find(str, "\'") and not string.find(str, "\"") then
        return "\"" .. str .. "\""
    else
        return "\'" .. M.escape_string(str) .. "\'"
    end
    end
end

-- 缩进字符串
function M.indent(str, level, indent_str)
    indent_str = indent_str or "  "
    local indent = string.rep(indent_str, level)
    
    -- 处理每一行
    local lines = {}
    for line in string.gmatch(str, "[^\n]*") do
        if #line > 0 then
            table.insert(lines, indent .. line)
        else
            table.insert(lines, line)
        end
    end
    
    return table.concat(lines, "\n")
end

-- 移除公共缩进
function M.dedent(str)
    local lines = {}
    local min_indent = math.huge
    
    -- 收集所有非空行
    for line in str:gmatch("[^\n]*") do
        table.insert(lines, line)
        if string.len(line) > 0 then
            local indent = string.match(line, "^(%s*)")
            min_indent = math.min(min_indent, string.len(indent))
        end
    end
    
    -- 移除公共缩进
    if min_indent < math.huge and min_indent > 0 then
        for i, line in ipairs(lines) do
            if #line > 0 then
                lines[i] = line:sub(min_indent + 1)
            end
        end
    end
    
    return table.concat(lines, "\n")
end

return M

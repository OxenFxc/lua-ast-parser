-- 字符扫描与位置跟踪

local M = {}

-- 导入工具模块
local position = require("lua.utils.position")
local string_ext = require("lua.utils.string_ext")

-- 扫描器类
local Scanner = {}
Scanner.__index = Scanner

-- 创建新的扫描器
function M.create(source)
    local self = setmetatable({}, Scanner)
    self.source = source
    self.length = #source
    self.position = 0  -- 当前位置（0-based）
    self.line = 1      -- 当前行号（1-based）
    self.column = 1    -- 当前列号（1-based）
    self.line_starts = {1}  -- 每行的起始偏移
    
    return self
end

-- 获取当前位置信息
function Scanner:get_location()
    return {
        line = self.line,
        column = self.column,
        offset = self.position
    }
end

-- 标记当前位置（用于创建 Token 范围）
function Scanner:mark_start()
    return {
        line = self.line,
        column = self.column,
        offset = self.position
    }
end

-- 创建从标记到当前位置的范围
function Scanner:create_span(mark)
    return {
        loc = {
            start = { line = mark.line, column = mark.column },
            ["end"] = { line = self.line, column = self.column }
        },
        range = { mark.offset, self.position }
    }
end

-- 前进 n 个字符
function Scanner:advance(n)
    n = n or 1
    for i = 1, n do
        if self.position >= self.length then
            return false
        end
        
        self.position = self.position + 1
        local char = self.source:sub(self.position, self.position)
        
        if char == "\n" then
            self.line = self.line + 1
            self.column = 1
            table.insert(self.line_starts, self.position + 1)
        elseif char == "\r" then
            -- 处理 \r\n
            if self.position < self.length and
               self.source:sub(self.position + 1, self.position + 1) == "\n" then
                self.position = self.position + 1
            end
            self.line = self.line + 1
            self.column = 1
            table.insert(self.line_starts, self.position + 1)
        else
            self.column = self.column + 1
        end
    end
    return true
end

-- 后退 n 个字符
function Scanner:retreat(n)
    n = n or 1
    for i = 1, n do
        if self.position <= 0 then
            return false
        end
        
        self.position = self.position - 1
        local char = self.source:sub(self.position, self.position)
        
        if char == "\n" then
            self.line = self.line - 1
            -- 重新计算当前行的列号
            local line_start = self.line_starts[self.line]
            self.column = self.position - line_start + 1
        elseif char == "\r" then
            self.line = self.line - 1
            local line_start = self.line_starts[self.line]
            self.column = self.position - line_start + 1
        else
            self.column = self.column - 1
        end
    end
    return true
end

-- 查看当前位置的字符（不前进）
function Scanner:peek(offset)
    offset = offset or 0
    local pos = self.position + offset
    if pos < 0 or pos >= self.length then
        return nil
    end
    return self.source:sub(pos + 1, pos + 1)
end

-- 查看接下来的 n 个字符（不前进）
function Scanner:peek_string(length)
    if self.position >= self.length then
        return ""
    end
    
    local end_pos = math.min(self.position + length, self.length)
    return self.source:sub(self.position + 1, end_pos)
end

-- 匹配字符序列
function Scanner:match(str)
    if self.position + #str > self.length then
        return false
    end
    
    local substr = self.source:sub(self.position + 1, self.position + #str)
    if substr == str then
        self:advance(#str)
        return true
    end
    
    return false
end

-- 跳过空白字符
function Scanner:skip_whitespace()
    while self.position < self.length do
        local char = self:peek()
        if not string_ext.is_whitespace(char) then
            break
        end
        self:advance()
    end
end

-- 读取直到指定字符序列或行尾
function Scanner:read_until(delimiters)
    local start_pos = self.position
    local result = ""
    
    while self.position < self.length do
        local char = self:peek()
        
        -- 检查是否匹配任何分隔符
        local found_delimiter = false
        for _, delimiter in ipairs(delimiters) do
            if self:peek_string(#delimiter) == delimiter then
                found_delimiter = true
                break
            end
        end
        
        if found_delimiter then
            break
        end
        
        -- 检查换行
        if char == "\n" or char == "\r" then
            break
        end
        
        result = result .. char
        self:advance()
    end
    
    return result, self.position - start_pos
end

-- 读取数字字面量
function Scanner:read_number()
    local start_pos = self.position
    local is_hex = false

    -- 检查是否为十六进制数字（以0x或0X开头）
    if self:peek() == "0" then
        local next_char = self:peek(1)
        if next_char == "x" or next_char == "X" then
            is_hex = true
            self:advance(2)  -- 跳过"0x"或"0X"
        end
    end

    if is_hex then
        -- 十六进制数字
        while self.position < self.length do
            local char = self:peek()
            if not string_ext.is_hex_digit(char) then
                break
            end
            self:advance()
        end
    else
        -- 十进制数字
        local has_dot = false
        local has_exp = false

        -- 整数部分
        while self.position < self.length do
            local char = self:peek()
            if not string_ext.is_digit(char) then
                break
            end
            self:advance()
        end

        -- 小数点
        if self:peek() == "." then
            has_dot = true
            self:advance()

            -- 小数部分
            while self.position < self.length do
                local char = self:peek()
                if not string_ext.is_digit(char) then
                    break
                end
                self:advance()
            end
        end

        -- 指数部分
        if self:peek() == "e" or self:peek() == "E" then
            has_exp = true
            self:advance()

            -- 指数符号
            if self:peek() == "+" or self:peek() == "-" then
                self:advance()
            end

            -- 指数数字
            while self.position < self.length do
                local char = self:peek()
                if not string_ext.is_digit(char) then
                    break
                end
                self:advance()
            end
        end
    end

    return self.source:sub(start_pos + 1, self.position)
end

-- 读取标识符
function Scanner:read_identifier()
    local start_pos = self.position
    
    -- 第一个字符
    local char = self:peek()
    if not string_ext.is_ident_start(char) then
        return ""
    end
    self:advance()
    
    -- 后续字符
    while self.position < self.length do
        local char = self:peek()
        if not string_ext.is_ident_char(char) then
            break
        end
        self:advance()
    end
    
    return self.source:sub(start_pos + 1, self.position)
end

-- 读取字符串字面量
function Scanner:read_string(quote)
    local start_pos = self.position
    local result = ""
    
    -- 跳过开始引号
    self:advance()
    
    while self.position < self.length do
        local char = self:peek()
        
        if char == quote then
            -- 结束引号
            self:advance()
            break
        elseif char == "\\" then
            -- 转义序列
            self:advance()
            if self.position >= self.length then
                return nil, "unterminated string"
            end
            
            local next_char = self:peek()
            if next_char == "n" then
                result = result .. "\n"
            elseif next_char == "r" then
                result = result .. "\r"
            elseif next_char == "t" then
                result = result .. "\t"
            elseif next_char == "\\" then
                result = result .. "\\"
            elseif next_char == "\"" then
                result = result .. "\""
            elseif next_char == "\'" then
                result = result .. "\'"
            elseif string_ext.is_digit(next_char) then
                -- 数字转义序列
                local num_str = ""
                for i = 1, 3 do
                    if not string_ext.is_digit(self:peek()) then
                        break
                    end
                    num_str = num_str .. self:peek()
                    self:advance()
                end
                local num = tonumber(num_str)
                if num and num <= 255 then
                    result = result .. string.char(num)
                else
                    return nil, "invalid escape sequence"
                end
                goto continue
            else
                result = result .. next_char
            end
            self:advance()
        else
            result = result .. char
            self:advance()
        end
        ::continue::
    end
    
    return result
end

-- 读取长字符串字面量
function Scanner:read_long_string()
    local start_pos = self.position
    local equals_count = 0
    
    -- 跳过 [
    self:advance()
    
    -- 计算等号数量
    while self:peek() == "=" do
        equals_count = equals_count + 1
        self:advance()
    end
    
    -- 跳过 [
    if self:peek() ~= "[" then
        return nil, "invalid long string delimiter"
    end
    self:advance()
    
    local result = ""
    local end_marker = "]" .. string.rep("=", equals_count) .. "]"
    
    while self.position < self.length do
        if self:match(end_marker) then
            break
        end
        
        result = result .. self:peek()
        self:advance()
    end
    
    return result
end

-- 检查是否到达文件末尾
function Scanner:is_at_end()
    return self.position >= self.length
end

return M

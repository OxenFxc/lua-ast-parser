-- 代码格式化策略

local M = {}

-- 格式化器类
local Formatter = {}
Formatter.__index = Formatter

-- 创建新的格式化器
function M.create(options)
    local self = setmetatable({}, Formatter)
    self.options = options or {}

    -- 默认格式化选项
    self.default_options = {
        indent = "  ",
        max_line_length = 80,
        semicolons = "omit",  -- "insert" | "omit" | "preserve"
        preserve_comments = true,
        insert_final_newline = true,
        quote_style = "auto",  -- "single" | "double" | "auto"
        array_style = "compact",  -- "compact" | "multiline"
        object_style = "compact"   -- "compact" | "multiline"
    }

    -- 合并选项
    for key, value in pairs(self.default_options) do
        if self.options[key] == nil then
            self.options[key] = value
        end
    end

    return self
end

-- 判断是否需要括号
function Formatter:needs_parentheses(node, parent_operator)
    if not parent_operator then
        return false
    end

    local precedence = require("lua.parser.precedence")
    return precedence.needs_parentheses(node.operator, parent_operator, false)
end

-- 判断表达式是否为简单表达式
function Formatter:is_simple_expression(node)
    if not node then
        return true
    end

    -- 简单表达式类型
    local simple_types = {
        Literal = true,
        Identifier = true
    }

    if simple_types[node.type] then
        return true
    end

    -- 简单的函数调用
    if node.type == "CallExpression" and
       node.base and node.base.type == "Identifier" and
       node.arguments and #node.arguments <= 2 then
        return true
    end

    -- 简单的二元表达式
    if node.type == "BinaryExpression" then
        return self:is_simple_expression(node.left) and
               self:is_simple_expression(node.right)
    end

    return false
end

-- 判断是否需要多行格式化
function Formatter:should_multiline(node, current_indent)
    if not node then
        return false
    end

    -- 基于节点类型判断
    if node.type == "TableConstructor" then
        return self:should_multiline_table(node)
    elseif node.type == "FunctionExpression" then
        return self:should_multiline_function(node)
    elseif node.type == "IfStatement" then
        return self:should_multiline_if(node)
    end

    return false
end

-- 判断表是否需要多行
function Formatter:should_multiline_table(node)
    if not node.fields or #node.fields == 0 then
        return false
    end

    -- 如果字段太多，使用多行
    if #node.fields > 3 then
        return true
    end

    -- 如果有复杂字段，使用多行
    for _, field in ipairs(node.fields) do
        if field.type == "TableKey" and not self:is_simple_expression(field.value) then
            return true
        end
    end

    return false
end

-- 判断函数是否需要多行
function Formatter:should_multiline_function(node)
    if not node.body or #node.body == 0 then
        return false
    end

    -- 如果语句太多，使用多行
    return #node.body > 2
end

-- 判断 if 语句是否需要多行
function Formatter:should_multiline_if(node)
    if not node.clauses then
        return false
    end

    -- 如果有多个子句，使用多行
    if #node.clauses > 1 then
        return true
    end

    -- 如果条件复杂，使用多行
    local first_clause = node.clauses[1]
    if first_clause and not self:is_simple_expression(first_clause.condition) then
        return true
    end

    return false
end

-- 计算最佳换行位置
function Formatter:find_best_break_point(nodes, max_length)
    if not nodes or #nodes == 0 then
        return 0
    end

    local total_length = 0
    for i, node in ipairs(nodes) do
        total_length = total_length + self:estimate_node_length(node)
        if total_length > max_length then
            return i - 1
        end
    end

    return #nodes
end

-- 估算节点长度
function Formatter:estimate_node_length(node)
    if not node then
        return 0
    end

    -- 简单估算
    if node.type == "Literal" then
        if node.value then
            return #tostring(node.value) + 2  -- 引号
        end
        return 4
    elseif node.type == "Identifier" then
        return #node.name
    elseif node.type == "BinaryExpression" then
        return self:estimate_node_length(node.left) +
               self:estimate_node_length(node.right) + 3  -- 操作符和空格
    elseif node.type == "CallExpression" then
        local length = self:estimate_node_length(node.base) + 2  -- 括号
        if node.arguments then
            for _, arg in ipairs(node.arguments) do
                length = length + self:estimate_node_length(arg) + 2  -- 逗号和空格
            end
        end
        return length
    end

    return 10  -- 默认长度
end

-- 格式化空白
function Formatter:format_whitespace(node, context)
    local result = ""

    if context and context.previous_token then
        -- 根据上下文决定是否需要空格
        local needs_space = self:needs_space_between(context.previous_token, node)
        if needs_space then
            result = " "
        end
    end

    return result
end

-- 判断两个 token 之间是否需要空格
function Formatter:needs_space_between(left, right)
    if not left or not right then
        return false
    end

    -- 运算符前后需要空格
    local operators = {
        ["+"] = true, ["-"] = true, ["*"] = true, ["/"] = true,
        ["="] = true, ["=="] = true, ["~="] = true, ["<"] = true,
        [">"] = true, ["<="] = true, [">="] = true
    }

    if operators[left.value] or operators[right.value] then
        return true
    end

    -- 关键字后需要空格
    local keywords = {
        ["if"] = true, ["then"] = true, ["else"] = true, ["elseif"] = true,
        ["for"] = true, ["in"] = true, ["do"] = true, ["while"] = true,
        ["repeat"] = true, ["until"] = true, ["function"] = true,
        ["local"] = true, ["return"] = true
    }

    if keywords[left.value] then
        return true
    end

    -- 标识符和字面量之间不需要额外空格
    if (left.type == "IDENTIFIER" or left.type == "Literal") and
       (right.type == "IDENTIFIER" or right.type == "Literal") then
        return false
    end

    return true
end

-- 格式化注释
function Formatter:format_comment(comment, context)
    if not comment or comment == "" then
        return ""
    end

    local lines = {}
    for line in comment:gmatch("[^\n]*") do
        table.insert(lines, line)
    end

    if #lines == 1 then
        -- 单行注释
        return "-- " .. lines[1]
    else
        -- 多行注释
        local result = "--[[\n"
        for _, line in ipairs(lines) do
            result = result .. "  " .. line .. "\n"
        end
        result = result .. "--]]"
        return result
    end
end

-- 获取格式化选项
function Formatter:get_option(key)
    return self.options[key]
end

-- 设置格式化选项
function Formatter:set_option(key, value)
    self.options[key] = value
end

return M

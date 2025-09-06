-- 运算符优先级定义

local M = {}

-- 运算符优先级表（从低到高）
-- 参考 Lua 5.1 规范：https://www.lua.org/manual/5.1/manual.html#2.5.6
M.PRECEDENCE = {
    -- 最低优先级：or
    ["or"] = 1,

    -- and
    ["and"] = 2,

    -- 比较运算符
    ["<"] = 3,
    [">"] = 3,
    ["<="] = 3,
    [">="] = 3,
    ["~="] = 3,
    ["=="] = 3,

    -- 位运算符（如果支持）
    ["|"] = 4,
    ["~"] = 5,
    ["&"] = 6,

    -- 位移运算符
    ["<<"] = 7,
    [">>"] = 7,

    -- 字符串连接
    [".."] = 8,

    -- 加减法
    ["+"] = 9,
    ["-"] = 9,

    -- 乘除法等
    ["*"] = 10,
    ["/"] = 10,
    ["//"] = 10,  -- 整数除法
    ["%"] = 10,

    -- 一元运算符（最高优先级）
    ["unary"] = 11,

    -- 幂运算
    ["^"] = 12
}

-- 结合性定义
M.ASSOCIATIVITY = {
    -- 左结合
    LEFT = "left",
    -- 右结合
    RIGHT = "right"
}

-- 运算符结合性表
M.OPERATOR_ASSOCIATIVITY = {
    -- 左结合运算符
    ["or"] = M.ASSOCIATIVITY.LEFT,
    ["and"] = M.ASSOCIATIVITY.LEFT,
    ["<"] = M.ASSOCIATIVITY.LEFT,
    [">"] = M.ASSOCIATIVITY.LEFT,
    ["<="] = M.ASSOCIATIVITY.LEFT,
    [">="] = M.ASSOCIATIVITY.LEFT,
    ["~="] = M.ASSOCIATIVITY.LEFT,
    ["=="] = M.ASSOCIATIVITY.LEFT,
    ["|"] = M.ASSOCIATIVITY.LEFT,
    ["~"] = M.ASSOCIATIVITY.LEFT,
    ["&"] = M.ASSOCIATIVITY.LEFT,
    ["<<"] = M.ASSOCIATIVITY.LEFT,
    [">>"] = M.ASSOCIATIVITY.LEFT,
    [".."] = M.ASSOCIATIVITY.LEFT,  -- 虽然是右结合，但解析时当作左结合处理
    ["+"] = M.ASSOCIATIVITY.LEFT,
    ["-"] = M.ASSOCIATIVITY.LEFT,
    ["*"] = M.ASSOCIATIVITY.LEFT,
    ["/"] = M.ASSOCIATIVITY.LEFT,
    ["//"] = M.ASSOCIATIVITY.LEFT,
    ["%"] = M.ASSOCIATIVITY.LEFT,

    -- 右结合运算符
    ["^"] = M.ASSOCIATIVITY.RIGHT
}

-- 检查运算符是否为二元运算符
function M.is_binary_operator(operator)
    return M.PRECEDENCE[operator] ~= nil and operator ~= "unary"
end

-- 检查运算符是否为一元运算符
function M.is_unary_operator(operator)
    return operator == "not" or operator == "-" or operator == "#"
end

-- 获取运算符优先级
function M.get_precedence(operator)
    return M.PRECEDENCE[operator] or 0
end

-- 获取运算符结合性
function M.get_associativity(operator)
    return M.OPERATOR_ASSOCIATIVITY[operator] or M.ASSOCIATIVITY.LEFT
end

-- 比较两个运算符的优先级
function M.compare_precedence(op1, op2)
    local p1 = M.get_precedence(op1)
    local p2 = M.get_precedence(op2)

    if p1 > p2 then
        return 1  -- op1 优先级更高
    elseif p1 < p2 then
        return -1  -- op2 优先级更高
    else
        return 0  -- 优先级相等
    end
end

-- 检查是否需要括号（用于代码生成）
function M.needs_parentheses(operator, parent_operator, is_right_child)
    if not parent_operator then
        return false
    end

    local op_prec = M.get_precedence(operator)
    local parent_prec = M.get_precedence(parent_operator)

    if op_prec > parent_prec then
        return false
    elseif op_prec < parent_prec then
        return true
    else
        -- 优先级相等，根据结合性决定
        local associativity = M.get_associativity(operator)
        if associativity == M.ASSOCIATIVITY.LEFT then
            -- 左结合：只有右侧子节点需要括号
            return is_right_child
        else
            -- 右结合：只有左侧子节点需要括号
            return not is_right_child
        end
    end
end

return M

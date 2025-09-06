-- 表操作扩展工具

local M = {}

-- 深度克隆表
function M.deep_clone(obj)
    if type(obj) ~= "table" then
        return obj
    end
    
    local result = {}
    
    for key, value in pairs(obj) do
        if type(value) == "table" then
            result[key] = M.deep_clone(value)
        else
            result[key] = value
        end
    end
    
    -- 复制元表
    setmetatable(result, getmetatable(obj))
    
    return result
end

-- 浅克隆表
function M.shallow_clone(obj)
    if type(obj) ~= "table" then
        return obj
    end
    
    local result = {}
    
    for key, value in pairs(obj) do
        result[key] = value
    end
    
    setmetatable(result, getmetatable(obj))
    
    return result
end

-- 合并表（右边覆盖左边）
function M.merge(left, right)
    local result = M.deep_clone(left)
    
    for key, value in pairs(right) do
        if type(value) == "table" and type(result[key]) == "table" then
            result[key] = M.merge(result[key], value)
        else
            result[key] = value
        end
    end
    
    return result
end

-- 检查表是否包含键
function M.has_key(tbl, key)
    return tbl[key] ~= nil
end

-- 检查表是否包含值
function M.has_value(tbl, value)
    for _, v in pairs(tbl) do
        if v == value then
            return true
        end
    end
    return false
end

-- 获取表的键列表
function M.keys(tbl)
    local result = {}
    for key in pairs(tbl) do
        table.insert(result, key)
    end
    return result
end

-- 获取表的值列表
function M.values(tbl)
    local result = {}
    for _, value in pairs(tbl) do
        table.insert(result, value)
    end
    return result
end

-- 获取表的键值对数量
function M.size(tbl)
    local count = 0
    for _ in pairs(tbl) do
        count = count + 1
    end
    return count
end

-- 检查表是否为空
function M.is_empty(tbl)
    return next(tbl) == nil
end

-- 反转表（键值互换）
function M.reverse(tbl)
    local result = {}
    for key, value in pairs(tbl) do
        result[value] = key
    end
    return result
end

-- 过滤表
function M.filter(tbl, predicate)
    local result = {}
    for key, value in pairs(tbl) do
        if predicate(key, value) then
            result[key] = value
        end
    end
    return result
end

-- 映射表
function M.map(tbl, transform)
    local result = {}
    for key, value in pairs(tbl) do
        local new_key, new_value = transform(key, value)
        result[new_key] = new_value
    end
    return result
end

-- 折叠表
function M.fold(tbl, initial, reducer)
    local result = initial
    for key, value in pairs(tbl) do
        result = reducer(result, key, value)
    end
    return result
end

-- 查找表中的元素
function M.find(tbl, predicate)
    for key, value in pairs(tbl) do
        if predicate(key, value) then
            return key, value
        end
    end
    return nil, nil
end

-- 检查两个表是否相等（深度比较）
function M.equals(left, right)
    if type(left) ~= type(right) then
        return false
    end
    
    if type(left) ~= "table" then
        return left == right
    end
    
    -- 检查键数量
    if M.size(left) ~= M.size(right) then
        return false
    end
    
    -- 检查所有键值对
    for key, value in pairs(left) do
        if type(value) == "table" then
            if not M.equals(value, right[key]) then
                return false
            end
        elseif value ~= right[key] then
            return false
        end
    end
    
    return true
end

-- 表格式化输出（用于调试）
function M.format(tbl, indent)
    indent = indent or 0
    local indent_str = string.rep("  ", indent)
    
    if type(tbl) ~= "table" then
        return tostring(tbl)
    end
    
    local result = "{\n"
    
    for key, value in pairs(tbl) do
        result = result .. indent_str .. "  "
        
        if type(key) == "string" then
            result = result .. string.format("[%q] = ", key)
        else
            result = result .. "[" .. tostring(key) .. "] = "
        end
        
        if type(value) == "table" then
            result = result .. M.format(value, indent + 1)
        elseif type(value) == "string" then
            result = result .. string.format("%q", value)
        else
            result = result .. tostring(value)
        end
        
        result = result .. ",\n"
    end
    
    result = result .. indent_str .. "}"
    return result
end

-- 创建只读表
function M.readonly(tbl)
    return setmetatable({}, {
        __index = tbl,
        __newindex = function(t, key, value)
            error("attempt to modify read-only table")
        end,
        __metatable = false
    })
end

-- 创建枚举类型
function M.create_enum(values)
    local enum = {}
    local reverse = {}
    
    for i, value in ipairs(values) do
        enum[value] = i
        reverse[i] = value
    end
    
    -- 设置元表使其不可修改
    return M.readonly(enum)
end

return M

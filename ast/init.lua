-- AST 模块主入口与工厂

local M = {}

-- 导入子模块
local nodes = require("lua.ast.nodes")
local visitor = require("lua.ast.visitor")

-- 导出节点类型常量
M.NodeType = nodes.NodeType

-- 导出节点构造函数
for name, func in pairs(nodes) do
    if string.sub(name, 1, 7) == "create_" then
        M[name] = func
    end
end

-- 导出节点工厂
M.NodeFactory = nodes.NodeFactory

-- 导出访问器相关
M.Visitor = visitor.Visitor
M.Traverser = visitor.Traverser
M.Collector = visitor.Collector
M.Transformer = visitor.Transformer

-- 导出访问器工厂方法
M.create_visitor = visitor.create
M.create_traverser = visitor.create_traverser
M.create_collector = visitor.create_collector
M.create_transformer = visitor.create_transformer

-- 扩展节点类型（插件机制）
M.registered_node_types = {}

-- 注册自定义节点类型
function M.register_node_type(type_name, config)
    M.registered_node_types[type_name] = config
    
    -- 如果有构造函数，添加到模块
    if config.constructor then
        M["create_" .. type_name:lower()] = config.constructor
    end
    
    -- 如果有访问器名称，添加到默认处理器
    if config.visitor_name then
        -- 这里可以扩展访问器默认处理器
    end
end

-- 获取已注册的节点类型
function M.get_registered_node_types()
    return M.registered_node_types
end

-- 节点验证
function M.validate_node(node)
    if not node or type(node) ~= "table" then
        return false, "Node must be a table"
    end
    
    if not node.type then
        return false, "Node must have a 'type' field"
    end
    
    if not node.loc then
        return false, "Node must have a 'loc' field"
    end
    
    if not node.range then
        return false, "Node must have a 'range' field"
    end
    
    -- 检查位置信息结构
    if type(node.loc) ~= "table" or not node.loc.start or not node.loc["end"] then
        return false, "Invalid 'loc' structure"
    end
    
    -- 检查范围信息结构
    if type(node.range) ~= "table" or #node.range ~= 2 then
        return false, "Invalid 'range' structure"
    end
    
    return true
end

-- 深度克隆节点（保持不可变性）
function M.clone_node(node)
    local table_ext = require("lua.utils.table_ext")
    return table_ext.deep_clone(node)
end

-- 比较两个节点（用于测试）
function M.equals_node(left, right)
    if not left or not right then
        return left == right
    end
    
    if type(left) ~= "table" or type(right) ~= "table" then
        return left == right
    end
    
    -- 比较基本字段
    if left.type ~= right.type then
        return false
    end
    
    -- 比较位置（近似比较）
    if left.loc and right.loc then
        if left.loc.start.line ~= right.loc.start.line or
           left.loc.start.column ~= right.loc.start.column then
            return false
        end
    end
    
    -- 比较其他字段
    local table_ext = require("lua.utils.table_ext")
    return table_ext.equals(left, right)
end

-- 格式化节点（用于调试）
function M.format_node(node, indent)
    indent = indent or 0
    local indent_str = string.rep("  ", indent)
    
    if not node or type(node) ~= "table" then
        return tostring(node)
    end
    
    local result = string.format("%s%s {\n", indent_str, node.type or "Unknown")
    
    for key, value in pairs(node) do
        if key ~= "type" then
            result = result .. string.format("%s  %s = ", indent_str, key)
            
            if type(value) == "table" then
                if value.type then
                    -- 子节点
                    result = result .. M.format_node(value, indent + 1)
                else
                    -- 普通表
                    result = result .. "{\n"
                    for k, v in pairs(value) do
                        result = result .. string.format("%s    %s = %s,\n", indent_str, k, tostring(v))
                    end
                    result = result .. string.format("%s  }", indent_str)
                end
            elseif type(value) == "string" then
                result = result .. string.format('"%s"', value)
            else
                result = result .. tostring(value)
            end
            
            result = result .. ",\n"
        end
    end
    
    result = result .. string.format("%s}", indent_str)
    return result
end

-- 节点统计信息
function M.collect_stats(node)
    local stats = {
        node_count = 0,
        node_types = {},
        max_depth = 0,
        total_lines = 0
    }
    
    local function traverse(current_node, depth)
        if not current_node or type(current_node) ~= "table" then
            return
        end
        
        stats.node_count = stats.node_count + 1
        stats.max_depth = math.max(stats.max_depth, depth)
        
        if current_node.type then
            stats.node_types[current_node.type] = (stats.node_types[current_node.type] or 0) + 1
        end
        
        if current_node.loc then
            local lines = current_node.loc["end"].line - current_node.loc.start.line + 1
            stats.total_lines = stats.total_lines + lines
        end
        
        -- 遍历子节点
        for _, value in pairs(current_node) do
            if type(value) == "table" then
                if value.type then
                    traverse(value, depth + 1)
                elseif value[1] then
                    -- 数组
                    for _, item in ipairs(value) do
                        if type(item) == "table" and item.type then
                            traverse(item, depth + 1)
                        end
                    end
                end
            end
        end
    end
    
    traverse(node, 0)
    return stats
end

-- 查找节点（按类型、位置等条件）
function M.find_nodes(node, predicate)
    local collector = M.create_collector(predicate)
    collector:collect(node)
    return collector:get_results()
end

-- 查找特定类型的节点
function M.find_nodes_by_type(node, node_type)
    return M.find_nodes(node, function(n)
        return n.type == node_type
    end)
end

-- 查找包含特定位置的节点
function M.find_node_at_position(node, line, column)
    local found = nil
    
    local function search(current)
        if not current or type(current) ~= "table" or not current.loc then
            return
        end
        
        local loc = current.loc
        if line >= loc.start.line and line <= loc["end"].line and
           (line > loc.start.line or column >= loc.start.column) and
           (line < loc["end"].line or column <= loc["end"].column) then
            found = current
            
            -- 继续搜索子节点，看是否有更精确的匹配
            for _, value in pairs(current) do
                if type(value) == "table" then
                    if value.type then
                        search(value)
                    elseif value[1] then
                        for _, item in ipairs(value) do
                            if type(item) == "table" and item.type then
                                search(item)
                            end
                        end
                    end
                end
            end
        end
    end
    
    search(node)
    return found
end

return M

-- 访问器模式实现

local M = {}

-- 访问器类
local Visitor = {}
Visitor.__index = Visitor

-- 创建新的访问器
function M.create(handlers)
    local self = setmetatable({}, Visitor)
    self.handlers = handlers or {}

    -- 默认处理器 - 使用闭包正确绑定self
    self.default_handlers = {}

    -- 创建带self绑定的处理器函数
    local function bind_handler(func)
        return function(node, context)
            return func(self, node, context)
        end
    end

    local function identity_handler(node, context)
        return node
    end

    -- 程序
    self.default_handlers.Program = bind_handler(function(self, node, context)
        return self:visit_children(node, context)
    end)

    -- 语句
    self.default_handlers.ExpressionStatement = bind_handler(function(self, node, context)
        return self:visit_children(node, context)
    end)
    self.default_handlers.LocalStatement = bind_handler(function(self, node, context)
        return self:visit_children(node, context)
    end)
    self.default_handlers.AssignmentStatement = bind_handler(function(self, node, context)
        return self:visit_children(node, context)
    end)
    self.default_handlers.FunctionDeclaration = bind_handler(function(self, node, context)
        return self:visit_children(node, context)
    end)
    self.default_handlers.IfStatement = bind_handler(function(self, node, context)
        return self:visit_children(node, context)
    end)
    self.default_handlers.WhileStatement = bind_handler(function(self, node, context)
        return self:visit_children(node, context)
    end)
    self.default_handlers.RepeatStatement = bind_handler(function(self, node, context)
        return self:visit_children(node, context)
    end)
    self.default_handlers.ForNumericStatement = bind_handler(function(self, node, context)
        return self:visit_children(node, context)
    end)
    self.default_handlers.ForGenericStatement = bind_handler(function(self, node, context)
        return self:visit_children(node, context)
    end)
    self.default_handlers.ReturnStatement = bind_handler(function(self, node, context)
        return self:visit_children(node, context)
    end)
    self.default_handlers.BreakStatement = identity_handler
    self.default_handlers.DoStatement = bind_handler(function(self, node, context)
        return self:visit_children(node, context)
    end)

    -- 表达式
    self.default_handlers.Literal = identity_handler
    self.default_handlers.Identifier = identity_handler
    self.default_handlers.BinaryExpression = bind_handler(function(self, node, context)
        return self:visit_children(node, context)
    end)
    self.default_handlers.UnaryExpression = bind_handler(function(self, node, context)
        return self:visit_children(node, context)
    end)
    self.default_handlers.AssignmentExpression = bind_handler(function(self, node, context)
        return self:visit_children(node, context)
    end)
    self.default_handlers.FunctionExpression = bind_handler(function(self, node, context)
        return self:visit_children(node, context)
    end)
    self.default_handlers.CallExpression = bind_handler(function(self, node, context)
        return self:visit_children(node, context)
    end)
    self.default_handlers.MemberExpression = bind_handler(function(self, node, context)
        return self:visit_children(node, context)
    end)
    self.default_handlers.TableConstructor = bind_handler(function(self, node, context)
        return self:visit_children(node, context)
    end)

    -- 表构造
    self.default_handlers.TableKey = bind_handler(function(self, node, context)
        return self:visit_children(node, context)
    end)
    self.default_handlers.TableKeyString = bind_handler(function(self, node, context)
        return self:visit_children(node, context)
    end)
    self.default_handlers.TableValue = bind_handler(function(self, node, context)
        return self:visit_children(node, context)
    end)

    -- 控制流子句
    self.default_handlers.IfClause = bind_handler(function(self, node, context)
        return self:visit_children(node, context)
    end)
    self.default_handlers.ElseifClause = bind_handler(function(self, node, context)
        return self:visit_children(node, context)
    end)
    self.default_handlers.ElseClause = bind_handler(function(self, node, context)
        return self:visit_children(node, context)
    end)

    return self
end

-- 访问节点
function Visitor:visit(node, context)
    if not node or type(node) ~= "table" or not node.type then
        return node
    end
    
    -- 获取处理器
    local handler = self.handlers[node.type] or self.default_handlers[node.type]
    
    if handler then
        return handler(node, context)
    else
        -- 未知节点类型，使用默认的子节点访问
        return self:visit_children(node, context)
    end
end

-- 访问子节点
function Visitor:visit_children(node, context)
    if not node or type(node) ~= "table" then
        return node
    end
    
    local result = {}
    
    -- 复制所有字段
    for key, value in pairs(node) do
        if type(value) == "table" then
            if self:is_node(value) then
                -- 单个节点
                result[key] = self:visit(value, context)
            elseif self:is_node_list(value) then
                -- 节点列表
                result[key] = self:visit_list(value, context)
            else
                -- 普通表，递归访问
                result[key] = self:visit_children(value, context)
            end
        else
            result[key] = value
        end
    end
    
    return result
end

-- 访问节点列表
function Visitor:visit_list(nodes, context)
    if not nodes or type(nodes) ~= "table" then
        return nodes
    end
    
    local result = {}
    for i, node in ipairs(nodes) do
        result[i] = self:visit(node, context)
    end
    
    return result
end

-- 判断是否为 AST 节点
function Visitor:is_node(obj)
    return type(obj) == "table" and obj.type and obj.loc and obj.range
end

-- 判断是否为节点列表
function Visitor:is_node_list(obj)
    if type(obj) ~= "table" then
        return false
    end
    
    -- 检查是否为数组风格的表
    local count = 0
    for _ in pairs(obj) do
        count = count + 1
    end
    
    -- 如果有数字索引，认为是节点列表
    return count > 0 and obj[1] ~= nil
end

-- 遍历器类（用于遍历 AST）
local Traverser = {}
Traverser.__index = Traverser

-- 创建遍历器
function M.create_traverser(handlers)
    local self = setmetatable({}, Traverser)
    self.handlers = handlers or {}
    
    -- 默认遍历处理器
    self.default_handlers = {
        enter = function(node, parent, key, index) end,
        exit = function(node, parent, key, index) end
    }
    
    return self
end

-- 深度优先遍历
function Traverser:traverse(node, parent, key, index)
    if not node or type(node) ~= "table" then
        return
    end
    
    -- 进入节点
    local enter_handler = self.handlers.enter or self.default_handlers.enter
    enter_handler(node, parent, key, index)
    
    -- 遍历子节点
    for child_key, child_value in pairs(node) do
        if type(child_value) == "table" then
            if self:is_node(child_value) then
                -- 单个节点
                self:traverse(child_value, node, child_key)
            elseif self:is_node_list(child_value) then
                -- 节点列表
                for i, child_node in ipairs(child_value) do
                    if self:is_node(child_node) then
                        self:traverse(child_node, node, child_key, i)
                    end
                end
            else
                -- 普通表，递归遍历
                self:traverse(child_value, node, child_key)
            end
        end
    end
    
    -- 离开节点
    local exit_handler = self.handlers.exit or self.default_handlers.exit
    exit_handler(node, parent, key, index)
end

-- 判断是否为 AST 节点
function Traverser:is_node(obj)
    return type(obj) == "table" and obj.type and obj.loc and obj.range
end

-- 判断是否为节点列表
function Traverser:is_node_list(obj)
    if type(obj) ~= "table" then
        return false
    end
    
    -- 检查是否为数组风格的表
    local count = 0
    for _ in pairs(obj) do
        count = count + 1
    end
    
    return count > 0 and obj[1] ~= nil
end

-- 收集器类（用于收集遍历结果）
local Collector = {}
Collector.__index = Collector

-- 创建收集器
function M.create_collector(predicate)
    local self = setmetatable({}, Collector)
    self.predicate = predicate
    self.results = {}
    return self
end

-- 收集节点
function Collector:collect(node)
    if self.predicate(node) then
        table.insert(self.results, node)
    end
    
    -- 递归收集子节点
    if type(node) == "table" then
        for _, child in pairs(node) do
            if type(child) == "table" then
                if child.type and child.loc then
                    -- 单个节点
                    self:collect(child)
                elseif child[1] then
                    -- 节点列表
                    for _, child_node in ipairs(child) do
                        if type(child_node) == "table" and child_node.type then
                            self:collect(child_node)
                        end
                    end
                end
            end
        end
    end
end

-- 获取结果
function Collector:get_results()
    return self.results
end

-- 转换器类（用于 AST 转换）
local Transformer = {}
Transformer.__index = Transformer

-- 创建转换器
function M.create_transformer(transformers)
    local self = setmetatable({}, Transformer)
    self.transformers = transformers or {}
    return self
end

-- 转换节点
function Transformer:transform(node)
    if not node or type(node) ~= "table" or not node.type then
        return node
    end
    
    -- 查找转换器
    local transformer = self.transformers[node.type]
    if transformer then
        -- 转换前先处理子节点
        local transformed_node = self:transform_children(node)
        -- 应用转换器
        return transformer(transformed_node)
    else
        -- 默认处理：只转换子节点
        return self:transform_children(node)
    end
end

-- 转换子节点
function Transformer:transform_children(node)
    if not node or type(node) ~= "table" then
        return node
    end
    
    local result = {}
    
    for key, value in pairs(node) do
        if type(value) == "table" then
            if value.type and value.loc then
                -- 单个节点
                result[key] = self:transform(value)
            elseif value[1] and type(value[1]) == "table" and value[1].type then
                -- 节点列表
                result[key] = {}
                for i, child_node in ipairs(value) do
                    result[key][i] = self:transform(child_node)
                end
            else
                -- 普通表
                result[key] = self:transform_children(value)
            end
        else
            result[key] = value
        end
    end
    
    return result
end

-- 导出主要类
M.Visitor = Visitor
M.Traverser = Traverser
M.Collector = Collector
M.Transformer = Transformer

return M

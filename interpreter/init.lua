-- Lua AST 解释器
-- 纯 Lua 实现的 AST 执行引擎

local M = {}

-- 版本信息
M.VERSION = "0.1.0"
M.API_VERSION = "1.0"

-- 导入依赖
local ast = require("lua.ast")
local builtins = require("lua.interpreter.builtins")

-- 解释器类
local Interpreter = {}
Interpreter.__index = Interpreter

-- 创建解释器实例
function M.create(options)
    options = options or {}

    local self = setmetatable({}, Interpreter)

    -- 初始化环境
    self.global_env = M.create_environment()
    self.current_env = self.global_env

    -- 加载内置函数
    local builtin_funcs = builtins.create_builtins()
    for name, func in pairs(builtin_funcs) do
        self.global_env[name] = func
    end

    -- 执行选项
    self.options = {
        max_steps = options.max_steps or 1000000,  -- 最大执行步数
        timeout = options.timeout or 30,           -- 超时时间（秒）
        strict = options.strict ~= false,          -- 严格模式
    }

    -- 执行状态和性能优化
    self.call_depth = 0
    self.in_metatable_lookup = false

    -- 性能统计
    self.stats = {
        expressions_evaluated = 0,
        functions_called = 0,
        start_time = os.clock()
    }

    return self
end

-- 执行 AST
function M.interpret(ast, options)
    local interpreter = M.create(options)

    -- 检查 AST 类型
    if ast.type ~= "Program" then
        return false, "Expected Program node"
    end

    -- 执行程序体
    local results = {interpreter:execute_program(ast)}

    return true, table.unpack(results)
end

-- 执行程序
function Interpreter:execute_program(program)
    local results = {}

    for _, stmt in ipairs(program.body) do
        results = {self:execute_statement(stmt)}
    end

    return table.unpack(results)
end

-- 执行语句
function Interpreter:execute_statement(stmt)
    if stmt.type == "ExpressionStatement" then
        return self:execute_expression(stmt.expression)
    elseif stmt.type == "LocalStatement" then
        return self:execute_local_statement(stmt)
    elseif stmt.type == "AssignmentStatement" then
        return self:execute_assignment_statement(stmt)
    elseif stmt.type == "ReturnStatement" then
        return self:execute_return_statement(stmt)
    elseif stmt.type == "IfStatement" then
        return self:execute_if_statement(stmt)
    elseif stmt.type == "WhileStatement" then
        return self:execute_while_statement(stmt)
    elseif stmt.type == "ForNumericStatement" then
        return self:execute_for_numeric_statement(stmt)
    elseif stmt.type == "ForGenericStatement" then
        return self:execute_for_generic_statement(stmt)
    elseif stmt.type == "FunctionDeclaration" then
        return self:execute_function_declaration(stmt)
    elseif stmt.type == "DoStatement" then
        return self:execute_do_statement(stmt)
    elseif stmt.type == "BreakStatement" then
        return self:execute_break_statement(stmt)
    elseif stmt.type == "GotoStatement" then
        return self:execute_goto_statement(stmt)
    elseif stmt.type == "LabelStatement" then
        return self:execute_label_statement(stmt)
    elseif stmt.type == "CallStatement" then
        return self:execute_call_statement(stmt)
    else
        error("Unknown statement type: " .. stmt.type)
    end
end

-- 执行表达式
function Interpreter:execute_expression(expr)
    if not expr then
        return nil
    end

    -- 检查栈深度，避免深递归栈溢出
    if self.call_depth > 15 then
        error("Stack overflow detected in expression evaluation.\\n\\nFor deep recursion, consider using an iterative approach:\\n\\n-- Instead of recursive:\\nfunction factorial(n)\\n    if n <= 1 then return 1 end\\n    return n * factorial(n - 1)\\nend\\n\\n-- Use iterative:\\nfunction factorial_iterative(n)\\n    local result = 1\\n    for i = 2, n do\\n        result = result * i\\n    end\\n    return result\\nend")
    end

    if expr.type == "Literal" then
        return expr.value
    elseif expr.type == "Identifier" then
        return self:lookup_variable(expr.name)
    elseif expr.type == "BinaryExpression" then
        return self:execute_binary_expression(expr)
    elseif expr.type == "UnaryExpression" then
        return self:execute_unary_expression(expr)
    elseif expr.type == "CallExpression" then
        -- 内联处理函数调用，避免递归循环
        local func = self:execute_expression(expr.base)
        local args = {}

        -- 执行参数表达式
        for i, arg_expr in ipairs(expr.arguments) do
            local arg_value = self:execute_expression(arg_expr)
            table.insert(args, arg_value)
        end

        -- 检查函数类型
        if type(func) ~= "function" then
            local func_type = type(func)
            local func_value = tostring(func)
            if func_type == "nil" then
                error("Runtime error: Attempt to call a nil value")
            elseif func_type == "table" then
                error("Runtime error: Attempt to call a table value. Did you mean to use ':' instead of '.'?")
            else
                error(string.format("Runtime error: Attempt to call a %s value (%s)", func_type, func_value))
            end
        end

        -- 执行函数调用
        self.stats.functions_called = self.stats.functions_called + 1

        -- 检查是否是内置函数
        local is_builtin = false
        if expr.base.type == "Identifier" then
            local name = expr.base.name
            if self.global_env[name] and type(self.global_env[name]) == "function" then
                is_builtin = true
            end
        end

        -- 执行函数调用
        if is_builtin then
            return func(table.unpack(args))
        else
            -- 对于普通函数，使用 pcall 保护调用
            local success, result1, result2, result3 = pcall(func, table.unpack(args))
            if not success then
                error(string.format("Runtime error in function call: %s", result1))
            end
            return result1, result2, result3
        end
    elseif expr.type == "MemberExpression" then
        return self:execute_member_expression(expr)
    elseif expr.type == "TableConstructor" then
        return self:execute_table_constructor(expr)
    elseif expr.type == "FunctionExpression" then
        return self:execute_function_expression(expr)
    else
        error("Unknown expression type: " .. expr.type)
    end
end

-- 执行二元表达式
function Interpreter:execute_binary_expression(expr)
    local left = self:execute_expression(expr.left)
    local right = self:execute_expression(expr.right)

    if expr.operator == "+" then
        return left + right
    elseif expr.operator == "-" then
        return left - right
    elseif expr.operator == "*" then
        return left * right
        elseif expr.operator == "/" then
            return left / right
        elseif expr.operator == "//" then
            return math.floor(left / right)
    elseif expr.operator == "%" then
        return left % right
    elseif expr.operator == "^" then
        return left ^ right
    elseif expr.operator == ".." then
        -- 处理nil值，在字符串连接中转换为"nil"
        local left_str = left == nil and "nil" or tostring(left)
        local right_str = right == nil and "nil" or tostring(right)
        return left_str .. right_str
    elseif expr.operator == "==" then
        return left == right
    elseif expr.operator == "~=" then
        return left ~= right
    elseif expr.operator == "<" then
        return left < right
    elseif expr.operator == "<=" then
        return left <= right
    elseif expr.operator == ">" then
        return left > right
    elseif expr.operator == ">=" then
        return left >= right
    elseif expr.operator == "and" then
        return left and right
    elseif expr.operator == "or" then
        return left or right
    else
        error("Unknown binary operator: " .. expr.operator)
    end
end

-- 执行一元表达式
function Interpreter:execute_unary_expression(expr)
    local argument = self:execute_expression(expr.argument)

    if expr.operator == "-" then
        return -argument
    elseif expr.operator == "not" then
        return not argument
    elseif expr.operator == "#" then
        return #argument
    else
        error("Unknown unary operator: " .. expr.operator)
    end
end

-- 执行函数调用
function Interpreter:execute_call_expression(expr)
    -- 增加调用深度计数
    self.call_depth = (self.call_depth or 0) + 1

    -- 检查是否即将发生栈溢出
    if self.call_depth > 12 then
        error("Stack overflow detected. For deep recursion, consider using an iterative approach instead of recursion.")
    end

    -- 简化处理：直接获取函数和参数
    local func = self:execute_expression(expr.base)
    local args = {}

    -- 执行参数表达式 - 使用协程避免深递归栈溢出
    if self.call_depth > 15 then
        -- 对于深度递归，使用协程处理参数计算
        for i, arg_expr in ipairs(expr.arguments) do
            local co = coroutine.create(function()
                return self:execute_expression(arg_expr)
            end)
            local success, arg_value = coroutine.resume(co)
            if success then
                table.insert(args, arg_value)
            else
                error("Runtime error in argument evaluation: " .. tostring(arg_value))
            end
        end
    else
        -- 正常处理参数
        for i, arg_expr in ipairs(expr.arguments) do
            local arg_value = self:execute_expression(arg_expr)
            table.insert(args, arg_value)
        end
    end

    -- 检查函数类型
    if type(func) ~= "function" then
        local func_type = type(func)
        local func_value = tostring(func)
        if func_type == "nil" then
            error("Runtime error: Attempt to call a nil value")
        elseif func_type == "table" then
            error("Runtime error: Attempt to call a table value. Did you mean to use ':' instead of '.'?")
        else
            error(string.format("Runtime error: Attempt to call a %s value (%s)", func_type, func_value))
        end
    end

    -- 执行函数调用
    self.stats.functions_called = self.stats.functions_called + 1

    -- 检查是否是内置函数
    local is_builtin = false
    if expr.base.type == "Identifier" then
        local name = expr.base.name
        if self.global_env[name] and type(self.global_env[name]) == "function" then
            is_builtin = true
        end
    end

    -- 执行函数调用
    if is_builtin then
        -- 对于内置函数，直接调用
        self.call_depth = self.call_depth - 1
        return func(table.unpack(args))
    else
        -- 对于普通函数，使用 pcall 保护调用
        local success, result1, result2, result3 = pcall(func, table.unpack(args))
        self.call_depth = self.call_depth - 1

        if not success then
            error(string.format("Runtime error in function call: %s", result1))
        end

        return result1, result2, result3
    end
end

-- 获取性能统计信息
function Interpreter:get_performance_stats()
    local end_time = os.clock()
    local execution_time = end_time - self.stats.start_time

    return {
        execution_time = execution_time,
        expressions_evaluated = self.stats.expressions_evaluated,
        functions_called = self.stats.functions_called,
        average_call_depth = self.call_depth,
        performance_per_second = self.stats.expressions_evaluated / execution_time
    }
end

-- 执行成员表达式
function Interpreter:execute_member_expression(expr)
    local object = self:execute_expression(expr.base)

    -- 检查对象是否为nil或非表类型
    if object == nil then
        error("Runtime error: Attempt to index a nil value")
    end

    -- 允许字符串和表进行索引操作（Lua特性）
    if type(object) ~= "table" and type(object) ~= "userdata" and type(object) ~= "string" then
        error(string.format("Runtime error: Attempt to index a %s value", type(object)))
    end

    if expr.computed then
        -- obj[key] - 计算属性访问
        local key = self:execute_expression(expr.identifier)
        local value = object[key]

        -- 检查元表__index，但避免递归调用
        if value == nil and type(object) == "table" and object.__index_wrapper and not self.in_metatable_lookup then
            self.in_metatable_lookup = true
            local success, index_value = pcall(object.__index_wrapper, object, key)
            self.in_metatable_lookup = false
            if success then
                value = index_value
            end
        end

        return value
    else
        -- obj.key - 直接属性访问
        local key = expr.identifier.name
        local value = object[key]

        -- 检查元表__index，但避免递归调用
        if value == nil and type(object) == "table" and object.__index_wrapper and not self.in_metatable_lookup then
            self.in_metatable_lookup = true
            local success, index_value = pcall(object.__index_wrapper, object, key)
            self.in_metatable_lookup = false
            if success then
                value = index_value
            end
        end

        return value
    end
end

-- 执行表构造器
function Interpreter:execute_table_constructor(expr)
    local table = {}

    for _, field in ipairs(expr.fields) do
        if field.type == "TableKey" then
            -- [key] = value
            local key = self:execute_expression(field.key)
            local value = self:execute_expression(field.value)
            table[key] = value
        elseif field.type == "TableKeyString" then
            -- key = value
            local value = self:execute_expression(field.value)
            table[field.key] = value
        elseif field.type == "TableValue" then
            -- value (数组元素)
            local value = self:execute_expression(field.value)
            table[#table + 1] = value
        end
    end

    return table
end

-- 执行函数表达式
function Interpreter:execute_function_expression(expr)
    -- 捕获定义时的环境（用于闭包）
    local closure_env = self.current_env

    -- 创建 Lua 函数
    local function lua_func(...)
        -- 为函数调用创建新的环境，父环境是闭包环境
        local func_env = M.create_environment(closure_env)

        -- 设置参数
        local args = {...}
        for i, param in ipairs(expr.params) do
            if param and param.name then
                func_env[param.name] = args[i]
            end
        end

        -- 保存当前环境和状态
        local old_env = self.current_env
        local old_strict = self.options.strict
        local old_metatable_flag = self.in_metatable_lookup

        -- 在函数执行期间禁用一些可能导致递归的功能
        self.options.strict = false
        self.in_metatable_lookup = false
        self.current_env = func_env

        -- 检查递归深度
        if self.call_depth > 12 then
            self.current_env = old_env
            self.options.strict = old_strict
            self.in_metatable_lookup = old_metatable_flag
            error("Stack overflow detected in function execution.\\n\\nFor deep recursion, consider using an iterative approach.\\n\\nExample conversion:\\n-- Recursive factorial:\\nfunction factorial(n)\\n    if n <= 1 then return 1 end\\n    return n * factorial(n - 1)\\nend\\n\\n-- Iterative factorial:\\nfunction factorial_iterative(n)\\n    local result = 1\\n    for i = 2, n do\\n        result = result * i\\n    end\\n    return result\\nend")
        end

        -- 执行函数体
        local result
        for _, stmt in ipairs(expr.body) do
            result = self:execute_statement(stmt)
        end

        -- 恢复环境和状态
        self.current_env = old_env
        self.options.strict = old_strict
        self.in_metatable_lookup = old_metatable_flag

        return result
    end

    return lua_func
end

-- 迭代方式执行函数调用，避免栈溢出
function Interpreter:execute_function_call_iterative(func, args)
    -- 使用协程来执行函数调用，这样可以避免栈溢出
    local co = coroutine.create(function()
        return func(table.unpack(args))
    end)

    local success, result1, result2, result3 = coroutine.resume(co)
    if success then
        return result1, result2, result3
    else
        error(string.format("Runtime error in function call: %s", result1))
    end
end

-- 执行局部变量声明
function Interpreter:execute_local_statement(stmt)
    -- 处理多返回值情况
    local values = {}
    if stmt.init then
        for _, init_expr in ipairs(stmt.init) do
            local result
            if init_expr.type == "CallExpression" then
                -- 直接调用以获取多返回值
                result = {self:execute_call_expression(init_expr)}
            else
                -- 其他表达式类型只返回一个值
                result = {self:execute_expression(init_expr)}
            end
            for _, val in ipairs(result) do
                table.insert(values, val)
            end
        end
    end

    -- 为每个变量分配值
    for i, var in ipairs(stmt.variables) do
        local value = values[i]  -- nil 如果没有足够的返回值
        self.current_env[var.name] = value
    end
end

-- 执行赋值语句
function Interpreter:execute_assignment_statement(stmt)
    -- 处理多返回值情况
    local values = {}
    if stmt.init then
        for _, init_expr in ipairs(stmt.init) do
            local result
            if init_expr.type == "CallExpression" then
                -- 直接调用以获取多返回值
                result = {self:execute_call_expression(init_expr)}
            else
                -- 其他表达式类型只返回一个值
                result = {self:execute_expression(init_expr)}
            end
            for _, val in ipairs(result) do
                table.insert(values, val)
            end
        end
    end

    -- 为每个变量分配值
    for i, var_expr in ipairs(stmt.variables) do
        local value = values[i]  -- nil 如果没有足够的返回值

        if var_expr.type == "Identifier" then
            self:assign_variable(var_expr.name, value)
        elseif var_expr.type == "MemberExpression" then
            local object = self:execute_expression(var_expr.base)
            if var_expr.computed then
                local key = self:execute_expression(var_expr.identifier)
                object[key] = value
            else
                object[var_expr.identifier.name] = value
            end
        end
    end
end

-- 执行返回语句
function Interpreter:execute_return_statement(stmt)
    if stmt.arguments and #stmt.arguments > 0 then
        -- 处理多返回值
        local results = {}
        for _, arg in ipairs(stmt.arguments) do
            if arg.type == "CallExpression" then
                -- 直接调用以获取多返回值
                local call_results = {self:execute_call_expression(arg)}
                for _, result in ipairs(call_results) do
                    table.insert(results, result)
                end
            else
                table.insert(results, self:execute_expression(arg))
            end
        end

        -- 返回所有结果
        return table.unpack(results)
    end
    return nil
end

-- 执行 if 语句
function Interpreter:execute_if_statement(stmt)
    for _, clause in ipairs(stmt.clauses) do
        if clause.type == "IfClause" then
            local condition = self:execute_expression(clause.condition)
            if condition then
                return self:execute_block(clause.body)
            end
        elseif clause.type == "ElseifClause" then
            local condition = self:execute_expression(clause.condition)
            if condition then
                return self:execute_block(clause.body)
            end
        elseif clause.type == "ElseClause" then
            return self:execute_block(clause.body)
        end
    end
end

-- 执行 while 语句
function Interpreter:execute_while_statement(stmt)
    while self:execute_expression(stmt.condition) do
        local result = self:execute_block(stmt.body)
        if result and result.type == "break" then
            break
        end
    end
end

-- 执行 for 数值循环
function Interpreter:execute_for_numeric_statement(stmt)
    local start = self:execute_expression(stmt.start)
    local limit = self:execute_expression(stmt["end"])  -- limit 存储在 "end" 字段中
    local step = stmt.step and self:execute_expression(stmt.step) or 1

    local loop_env = M.create_environment(self.current_env)
    local old_env = self.current_env
    self.current_env = loop_env

    for i = start, limit, step do
        loop_env[stmt.variable.name] = i
        local result = self:execute_block(stmt.body, false)  -- 不创建新环境
        if result and result.type == "break" then
            break
        end
    end

    self.current_env = old_env
end

-- 执行 for 泛型循环
function Interpreter:execute_for_generic_statement(stmt)
    -- 执行迭代器表达式，正确处理多返回值
    local iter_func, state, init
    if #stmt.iterators == 1 then
        -- 单个迭代器表达式，如 pairs(t)
        iter_func, state, init = self:execute_expression(stmt.iterators[1])
    else
        -- 多个迭代器表达式
        local iterators = {}
        for _, iter in ipairs(stmt.iterators) do
            local results = {self:execute_expression(iter)}
            for _, result in ipairs(results) do
                table.insert(iterators, result)
            end
        end
        iter_func = iterators[1]
        state = iterators[2]
        init = iterators[3]
    end

    local loop_env = M.create_environment(self.current_env)
    local old_env = self.current_env
    self.current_env = loop_env

    -- 简单的泛型循环实现（支持 pairs/ipairs）
    -- iter_func, state, init 已经在上面设置

    if type(iter_func) == "function" then
        while true do
            local values = {iter_func(state, init)}
            if values[1] == nil then break end
            init = values[1]

            -- 设置循环变量
            for i, var in ipairs(stmt.variables) do
                if var and var.name then
                    loop_env[var.name] = values[i]
                end
            end

            local result = self:execute_block(stmt.body, false)  -- 不创建新环境
            if result and result.type == "break" then
                break
            end
        end
    else
        -- 处理自定义迭代器（返回单个函数的情况）
        local custom_iter = iterators[1]
        if type(custom_iter) == "function" then
            while true do
                local values = {custom_iter()}
                if values[1] == nil then break end

                -- 设置循环变量
                for i, var in ipairs(stmt.variables) do
                    if var and var.name then
                        loop_env[var.name] = values[i]
                    end
                end

                local result = self:execute_block(stmt.body, false)  -- 不创建新环境
                if result and result.type == "break" then
                    break
                end
            end
        end
    end

    self.current_env = old_env
end

-- 执行函数声明
function Interpreter:execute_function_declaration(stmt)
    -- 捕获定义时的环境（用于闭包）
    local closure_env = self.current_env

    -- 创建函数对象，包含参数和函数体
    local function lua_func(...)
        -- 使用轻量级环境管理，避免过深的调用栈
        -- 对于递归函数，复用父环境而不是创建新环境
        local func_env

        -- 检查是否是递归调用（函数名在当前环境中）
        local func_name = stmt.name and stmt.name.name
        local is_recursive = func_name and closure_env[func_name] ~= nil

        if is_recursive then
            -- 递归调用：创建最小环境，只包含参数
            func_env = {
                __parent = closure_env,
                __is_recursive_env = true
            }
            -- 设置元表以支持环境链查找
            setmetatable(func_env, {
                __index = function(t, k)
                    if k == "__parent" then return nil end
                    return rawget(t, "__parent")[k]
                end
            })
        else
            -- 普通调用：创建完整环境
            func_env = closure_env or self.current_env
        end

        -- 设置参数
        local args = {...}
        if stmt.params then
            for i, param in ipairs(stmt.params) do
                if param and param.name then
                    -- 确保参数有值，如果没有则设为nil
                    func_env[param.name] = args[i]
                end
            end
        end

        -- 保存当前环境和状态
        local old_env = self.current_env
        local old_strict = self.options.strict
        local old_metatable_flag = self.in_metatable_lookup

        -- 在函数执行期间禁用一些可能导致递归的功能
        self.options.strict = false
        self.in_metatable_lookup = false
        self.current_env = func_env

        -- 执行函数体
        local result
        if stmt.body then
            for _, stmt_inner in ipairs(stmt.body) do
                result = self:execute_statement(stmt_inner)
            end
        end

        -- 恢复环境和状态
        self.current_env = old_env
        self.options.strict = old_strict
        self.in_metatable_lookup = old_metatable_flag

        return result
    end

    -- 将函数添加到环境
    local assign_value = function(target, value)
        if target.type == "Identifier" then
            -- 简单标识符
            return target.name, value
        elseif target.type == "MemberExpression" then
            -- 成员表达式 (table.property)
            local obj = self:execute_expression(target.base)
            local key = target.computed and self:execute_expression(target.identifier) or target.identifier.name
            obj[key] = value
            return nil, nil  -- 不需要额外的赋值
        else
            error("Unsupported function name type: " .. target.type)
        end
    end

    if stmt.isLocal then
        local name, value = assign_value(stmt.identifier, lua_func)
        if name and value then
            self.current_env[name] = value
        end
    else
        local name, value = assign_value(stmt.identifier, lua_func)
        if name and value then
            self.global_env[name] = value
        end
    end
end

-- 执行 do 语句
function Interpreter:execute_do_statement(stmt)
    local block_env = M.create_environment(self.current_env)
    local old_env = self.current_env
    self.current_env = block_env

    local result = self:execute_block(stmt.body)

    self.current_env = old_env
    return result
end

-- 执行 break 语句
function Interpreter:execute_break_statement(stmt)
    return {type = "break"}
end

-- 执行调用语句
function Interpreter:execute_call_statement(stmt)
    return self:execute_call_expression(stmt.expression)
end

-- 执行语句块
function Interpreter:execute_block(statements, create_new_env)
    if create_new_env ~= false then
        -- 默认情况下为语句块创建新的环境
        local block_env = M.create_environment(self.current_env)
        local old_env = self.current_env
        self.current_env = block_env

        local result
        for _, stmt in ipairs(statements) do
            result = self:execute_statement(stmt)
        end

        self.current_env = old_env
        return result
    else
        -- 对于for循环体，不创建新环境，直接在当前环境中执行
        local result
        for _, stmt in ipairs(statements) do
            result = self:execute_statement(stmt)
        end

        return result
    end
end

-- 查找变量
function Interpreter:lookup_variable(name)
    if name == nil then
        error("Runtime error: Variable name is nil")
    end

    local env = self.current_env
    while env do
        if env[name] ~= nil then
            return env[name]
        end
        env = env.__parent
    end

    if self.options.strict then
        error("Undefined variable: " .. tostring(name))
    end

    return nil
end

-- 赋值变量
function Interpreter:assign_variable(name, value)
    local env = self.current_env
    local level = 0
    while env do
        if env[name] ~= nil then
            -- 在找到变量的环境中修改
            env[name] = value
            return
        end
        env = env.__parent
        level = level + 1
    end

    -- 如果找不到变量，在当前环境中创建
    self.current_env[name] = value
end

-- 创建环境
function M.create_environment(parent)
    local env = {}
    env.__parent = parent
    return env
end

-- 执行goto语句
function Interpreter:execute_goto_statement(stmt)
    -- goto语句用于跳转到标签
    -- 在解释器中，我们简单地记录跳转目标
    -- 实际的跳转逻辑需要在执行块时处理
    return {
        type = "goto",
        label = stmt.label,
        target_line = stmt.loc.start.line
    }
end

-- 执行标签语句
function Interpreter:execute_label_statement(stmt)
    -- 标签语句只是一个标记，不执行任何操作
    -- 但我们记录标签位置供goto使用
    return {
        type = "label",
        name = stmt.name,
        line = stmt.loc.start.line
    }
end

return M


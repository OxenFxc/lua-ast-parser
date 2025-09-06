-- 示例插件集合
-- 展示插件系统的各种功能

local M = {}

-- 插件1：自定义操作符插件
M.custom_operators_plugin = {
    name = "custom_operators",
    version = "1.0.0",
    description = "添加自定义操作符支持",

    -- 自定义操作符处理
    operators = {
        ["//"] = function(a, b) return math.floor(a / b) end,
        ["**"] = function(a, b) return a ^ b end,
        ["%%"] = function(a, b) return a % b end
    },

    -- 初始化
    init = function(config)
        print("Custom operators plugin initialized")
        -- 这里可以注册新的Token类型
    end,

    -- 扩展解释器
    extend_interpreter = function(interpreter)
        -- 为解释器添加自定义操作符支持
        local original_execute_binary = interpreter.execute_binary_expression

        interpreter.execute_binary_expression = function(self, expr)
            -- 检查是否为自定义操作符
            if M.custom_operators_plugin.operators[expr.operator] then
                local left = self:execute_expression(expr.left)
                local right = self:execute_expression(expr.right)
                local op_func = M.custom_operators_plugin.operators[expr.operator]
                return op_func(left, right)
            else
                -- 使用原始方法
                return original_execute_binary(self, expr)
            end
        end
    end,

    -- 清理
    cleanup = function()
        print("Custom operators plugin cleaned up")
    end
}

-- 插件2：Lua 5.2兼容性插件
M.lua52_compatibility_plugin = {
    name = "lua52_compatibility",
    version = "1.0.0",
    description = "Lua 5.2兼容性支持",

    -- 初始化
    init = function(config)
        print("Lua 5.2 compatibility plugin initialized")
    end,

    -- 扩展内置函数
    extend_builtins = function(builtins)
        -- 添加Lua 5.2特有的函数
        builtins.bit32 = builtins.bit32 or {
            band = function(a, b) return a & b end,
            bor = function(a, b) return a | b end,
            bxor = function(a, b) return a ~ b end,
            bnot = function(a) return ~a end,
            lshift = function(a, n) return a << n end,
            rshift = function(a, n) return a >> n end
        }

        builtins.table.pack = function(...)
            return {n = select("#", ...), ...}
        end

        builtins.table.unpack = function(t, i, j)
            i = i or 1
            j = j or t.n or #t
            return table.unpack(t, i, j)
        end
    end,

    -- 清理
    cleanup = function()
        print("Lua 5.2 compatibility plugin cleaned up")
    end
}

-- 插件3：代码优化插件
M.code_optimizer_plugin = {
    name = "code_optimizer",
    version = "1.0.0",
    description = "代码优化插件",

    -- 初始化
    init = function(config)
        print("Code optimizer plugin initialized")
    end,

    -- 扩展AST节点类型
    extend_ast_nodes = function(ast)
        -- 注册优化相关的节点类型
        ast.register_node_type("OptimizedExpression", {
            constructor = function(value)
                return {
                    type = "OptimizedExpression",
                    value = value,
                    loc = {start = {line = 0, column = 0}, ["end"] = {line = 0, column = 0}},
                    range = {0, 0}
                }
            end
        })
    end,

    -- 扩展解释器
    extend_interpreter = function(interpreter)
        -- 添加常量折叠优化
        local original_execute_binary = interpreter.execute_binary_expression

        interpreter.execute_binary_expression = function(self, expr)
            -- 常量折叠优化
            if expr.left.type == "Literal" and expr.right.type == "Literal" then
                if expr.operator == "+" then
                    return expr.left.value + expr.right.value
                elseif expr.operator == "-" then
                    return expr.left.value - expr.right.value
                elseif expr.operator == "*" then
                    return expr.left.value * expr.right.value
                elseif expr.operator == "/" then
                    return expr.left.value / expr.right.value
                end
            end

            return original_execute_binary(self, expr)
        end
    end,

    -- 清理
    cleanup = function()
        print("Code optimizer plugin cleaned up")
    end
}

-- 插件4：调试增强插件
M.debug_enhancement_plugin = {
    name = "debug_enhancement",
    version = "1.0.0",
    description = "调试增强功能",

    -- 初始化
    init = function(config)
        print("Debug enhancement plugin initialized")
        self.trace_enabled = config.trace_enabled or false
    end,

    -- 扩展解释器
    extend_interpreter = function(interpreter)
        -- 添加执行跟踪
        local original_execute_statement = interpreter.execute_statement

        interpreter.execute_statement = function(self, stmt)
            if self.trace_enabled then
                print("Executing: " .. stmt.type)
            end

            local result = original_execute_statement(self, stmt)

            if self.trace_enabled and stmt.loc then
                print(string.format("Completed at line %d", stmt.loc.start.line))
            end

            return result
        end

        -- 添加断点支持
        interpreter.breakpoints = {}

        interpreter.set_breakpoint = function(self, line)
            self.breakpoints[line] = true
        end

        interpreter.remove_breakpoint = function(self, line)
            self.breakpoints[line] = nil
        end

        interpreter.check_breakpoint = function(self, line)
            if self.breakpoints[line] then
                print("Breakpoint hit at line " .. line)
                -- 这里可以添加交互式调试
                return true
            end
            return false
        end
    end,

    -- 扩展内置函数
    extend_builtins = function(builtins)
        builtins.debug.set_breakpoint = function(line)
            -- 获取当前解释器实例（简化实现）
            print("Setting breakpoint at line " .. line)
        end

        builtins.debug.remove_breakpoint = function(line)
            print("Removing breakpoint at line " .. line)
        end
    end,

    -- 清理
    cleanup = function()
        print("Debug enhancement plugin cleaned up")
    end
}

-- 插件5：宏系统插件
M.macro_system_plugin = {
    name = "macro_system",
    version = "1.0.0",
    description = "简单的宏系统",

    macros = {},

    -- 初始化
    init = function(config)
        print("Macro system plugin initialized")
    end,

    -- 定义宏
    define_macro = function(name, expansion)
        M.macro_system_plugin.macros[name] = expansion
    end,

    -- 扩展词法器
    extend_lexer = function(lexer)
        -- 这里可以添加宏展开逻辑
        -- 在词法分析阶段替换宏
    end,

    -- 扩展语法器
    extend_parser = function(parser)
        -- 添加宏语法支持
    end,

    -- 扩展解释器
    extend_interpreter = function(interpreter)
        -- 添加宏展开支持
        local original_execute_identifier = interpreter.execute_identifier

        interpreter.execute_identifier = function(self, expr)
            local name = expr.name

            -- 检查是否为宏
            if M.macro_system_plugin.macros[name] then
                -- 执行宏展开
                local expansion = M.macro_system_plugin.macros[name]
                if type(expansion) == "function" then
                    return expansion()
                else
                    return expansion
                end
            end

            return original_execute_identifier(self, expr)
        end
    end,

    -- 清理
    cleanup = function()
        print("Macro system plugin cleaned up")
        M.macro_system_plugin.macros = {}
    end
}

-- 注册所有示例插件
function M.register_example_plugins(plugin_manager)
    plugin_manager:register(M.custom_operators_plugin)
    plugin_manager:register(M.lua52_compatibility_plugin)
    plugin_manager:register(M.code_optimizer_plugin)
    plugin_manager:register(M.debug_enhancement_plugin)
    plugin_manager:register(M.macro_system_plugin)
end

return M

-- AST 打印器主控制器

local M = {}

-- 导入依赖
local ast = require("lua.ast")
local emitter = require("lua.printer.emitter")
local formatter = require("lua.printer.formatter")

-- 打印器类
local Printer = {}
Printer.__index = Printer

-- 创建新的打印器
function M.create(options)
    local self = setmetatable({}, Printer)
    self.options = options or {}
    self.emitter = emitter.create(self.options)
    self.formatter = formatter.create(self.options)

    -- 节点打印函数映射
    self.node_printers = {
        -- 程序
        Program = function(node) return self:print_program(node) end,

        -- 语句
        ExpressionStatement = function(node) return self:print_expression_statement(node) end,
        LocalStatement = function(node) return self:print_local_statement(node) end,
        AssignmentStatement = function(node) return self:print_assignment_statement(node) end,
        FunctionDeclaration = function(node) return self:print_function_declaration(node) end,
        IfStatement = function(node) return self:print_if_statement(node) end,
        WhileStatement = function(node) return self:print_while_statement(node) end,
        RepeatStatement = function(node) return self:print_repeat_statement(node) end,
        ForNumericStatement = function(node) return self:print_for_numeric_statement(node) end,
        ForGenericStatement = function(node) return self:print_for_generic_statement(node) end,
        ReturnStatement = function(node) return self:print_return_statement(node) end,
        BreakStatement = function(node) return self:print_break_statement(node) end,
        DoStatement = function(node) return self:print_do_statement(node) end,
        GotoStatement = function(node) return self:print_goto_statement(node) end,
        LabelStatement = function(node) return self:print_label_statement(node) end,

        -- 表达式
        Literal = function(node) return self:print_literal(node) end,
        Identifier = function(node) return self:print_identifier(node) end,
        BinaryExpression = function(node) return self:print_binary_expression(node) end,
        UnaryExpression = function(node) return self:print_unary_expression(node) end,
        AssignmentExpression = function(node) return self:print_assignment_expression(node) end,
        FunctionExpression = function(node) return self:print_function_expression(node) end,
        CallExpression = function(node) return self:print_call_expression(node) end,
        MemberExpression = function(node) return self:print_member_expression(node) end,
        TableConstructor = function(node) return self:print_table_constructor(node) end,

        -- 表构造
        TableKey = function(node) return self:print_table_key(node) end,
        TableKeyString = function(node) return self:print_table_key_string(node) end,
        TableValue = function(node) return self:print_table_value(node) end,

        -- 控制流子句
        IfClause = function(node) return self:print_if_clause(node) end,
        ElseifClause = function(node) return self:print_elseif_clause(node) end,
        ElseClause = function(node) return self:print_else_clause(node) end
    }

    return self
end

-- 主打印入口
function M.print(ast_node, options)
    local printer = M.create(options)
    local success, result = pcall(function()
        return printer:print_node(ast_node)
    end)

    if success then
        -- 添加最终换行符
        if printer.options.insert_final_newline then
            printer.emitter:emit_newline()
        end

        local code = printer.emitter:get_output()
        return true, { code = code }
    else
        return false, { error = result }
    end
end

-- 打印 AST 节点
function Printer:print_node(node)
    if not node or type(node) ~= "table" or not node.type then
        return ""
    end

    local printer_func = self.node_printers[node.type]
    if printer_func then
        return printer_func(node)
    else
        -- 未知节点类型，使用通用处理
        return self:print_unknown_node(node)
    end
end

-- 打印程序
function Printer:print_program(node)
    for i, stmt in ipairs(node.body or {}) do
        self:print_node(stmt)

        -- 添加分号（根据选项）
        if self.options.semicolons ~= "omit" then
            self.emitter:emit_semicolon()
        end

        -- 添加换行（除了最后一个语句）
        if i < #node.body then
            self.emitter:emit_newline()
        end
    end
end

-- 打印表达式语句
function Printer:print_expression_statement(node)
    self:print_node(node.expression)
end

-- 打印本地语句
function Printer:print_local_statement(node)
    self.emitter:emit("local ")

    -- 打印变量列表
    for i, var in ipairs(node.variables or {}) do
        self:print_node(var)
        if i < #node.variables then
            self.emitter:emit(", ")
        end
    end

    -- 打印初始化表达式
    if node.init and #node.init > 0 then
        self.emitter:emit(" = ")
        for i, expr in ipairs(node.init) do
            self:print_node(expr)
            if i < #node.init then
                self.emitter:emit(", ")
            end
        end
    end
end

-- 打印赋值语句
function Printer:print_assignment_statement(node)
    -- 打印变量列表
    for i, var in ipairs(node.variables or {}) do
        self:print_node(var)
        if i < #node.variables then
            self.emitter:emit(", ")
        end
    end

    -- 打印赋值操作符
    self.emitter:emit(" = ")

    -- 打印表达式列表
    for i, expr in ipairs(node.init or {}) do
        self:print_node(expr)
        if i < #node.init then
            self.emitter:emit(", ")
        end
    end
end

-- 打印函数声明
function Printer:print_function_declaration(node)
    if node.isLocal then
        self.emitter:emit("local ")
    end

    self.emitter:emit("function ")
    self:print_node(node.identifier)

    -- 打印参数列表
    self.emitter:emit("(")
    for i, param in ipairs(node.params or {}) do
        self:print_node(param)
        if i < #node.params then
            self.emitter:emit(", ")
        end
    end
    self.emitter:emit(")")

    -- 打印函数体
    self.emitter:emit_newline()
    self.emitter:increase_indent()

    for i, stmt in ipairs(node.body or {}) do
        self.emitter:emit_indented("")
        self:print_node(stmt)
        if i < #node.body then
            self.emitter:emit_newline()
        end
    end

    self.emitter:decrease_indent()
    self.emitter:emit_newline()
    self.emitter:emit_indented("end")
end

-- 打印 if 语句
function Printer:print_if_statement(node)
    for i, clause in ipairs(node.clauses or {}) do
        if i == 1 then
            self:print_if_clause(clause)
        elseif clause.type == "ElseifClause" then
            self.emitter:emit_newline()
            self:print_elseif_clause(clause)
        elseif clause.type == "ElseClause" then
            self.emitter:emit_newline()
            self:print_else_clause(clause)
        end
    end

    self.emitter:emit_newline()
    self.emitter:emit_indented("end")
end

-- 打印 if 子句
function Printer:print_if_clause(node)
    self.emitter:emit("if ")
    self:print_node(node.condition)
    self.emitter:emit(" then")
    self.emitter:emit_newline()

    self.emitter:increase_indent()
    for _, stmt in ipairs(node.body or {}) do
        self.emitter:emit_indented("")
        self:print_node(stmt)
        self.emitter:emit_newline()
    end
    self.emitter:decrease_indent()
end

-- 打印 elseif 子句
function Printer:print_elseif_clause(node)
    self.emitter:emit_indented("elseif ")
    self:print_node(node.condition)
    self.emitter:emit(" then")
    self.emitter:emit_newline()

    self.emitter:increase_indent()
    for _, stmt in ipairs(node.body or {}) do
        self.emitter:emit_indented("")
        self:print_node(stmt)
        self.emitter:emit_newline()
    end
    self.emitter:decrease_indent()
end

-- 打印 else 子句
function Printer:print_else_clause(node)
    self.emitter:emit_indented("else")
    self.emitter:emit_newline()

    self.emitter:increase_indent()
    for _, stmt in ipairs(node.body or {}) do
        self.emitter:emit_indented("")
        self:print_node(stmt)
        self.emitter:emit_newline()
    end
    self.emitter:decrease_indent()
end

-- 打印 while 语句
function Printer:print_while_statement(node)
    self.emitter:emit("while ")
    self:print_node(node.condition)
    self.emitter:emit(" do")
    self.emitter:emit_newline()

    self.emitter:increase_indent()
    for _, stmt in ipairs(node.body or {}) do
        self.emitter:emit_indented("")
        self:print_node(stmt)
        self.emitter:emit_newline()
    end
    self.emitter:decrease_indent()

    self.emitter:emit_indented("end")
end

-- 打印 repeat 语句
function Printer:print_repeat_statement(node)
    self.emitter:emit("repeat")
    self.emitter:emit_newline()

    self.emitter:increase_indent()
    for _, stmt in ipairs(node.body or {}) do
        self.emitter:emit_indented("")
        self:print_node(stmt)
        self.emitter:emit_newline()
    end
    self.emitter:decrease_indent()

    self.emitter:emit_indented("until ")
    self:print_node(node.condition)
end

-- 打印数值 for 语句
function Printer:print_for_numeric_statement(node)
    self.emitter:emit("for ")
    self:print_node(node.variable)
    self.emitter:emit(" = ")
    self:print_node(node.start)
    self.emitter:emit(", ")
    self:print_node(node["end"])
    if node.step then
        self.emitter:emit(", ")
        self:print_node(node.step)
    end
    self.emitter:emit(" do")
    self.emitter:emit_newline()

    self.emitter:increase_indent()
    for _, stmt in ipairs(node.body or {}) do
        self.emitter:emit_indented("")
        self:print_node(stmt)
        self.emitter:emit_newline()
    end
    self.emitter:decrease_indent()

    self.emitter:emit_indented("end")
end

-- 打印泛型 for 语句
function Printer:print_for_generic_statement(node)
    self.emitter:emit("for ")

    -- 打印变量列表
    for i, var in ipairs(node.variables or {}) do
        self:print_node(var)
        if i < #node.variables then
            self.emitter:emit(", ")
        end
    end

    self.emitter:emit(" in ")

    -- 打印迭代器列表
    for i, iter in ipairs(node.iterators or {}) do
        self:print_node(iter)
        if i < #node.iterators then
            self.emitter:emit(", ")
        end
    end

    self.emitter:emit(" do")
    self.emitter:emit_newline()

    self.emitter:increase_indent()
    for _, stmt in ipairs(node.body or {}) do
        self.emitter:emit_indented("")
        self:print_node(stmt)
        self.emitter:emit_newline()
    end
    self.emitter:decrease_indent()

    self.emitter:emit_indented("end")
end

-- 打印 return 语句
function Printer:print_return_statement(node)
    self.emitter:emit("return")

    if node.arguments and #node.arguments > 0 then
        self.emitter:emit(" ")
        for i, arg in ipairs(node.arguments) do
            self:print_node(arg)
            if i < #node.arguments then
                self.emitter:emit(", ")
            end
        end
    end
end

-- 打印 break 语句
function Printer:print_break_statement(node)
    self.emitter:emit("break")
end

-- 打印 do 语句
function Printer:print_do_statement(node)
    self.emitter:emit("do")
    self.emitter:emit_newline()

    self.emitter:increase_indent()
    for _, stmt in ipairs(node.body or {}) do
        self.emitter:emit_indented("")
        self:print_node(stmt)
        self.emitter:emit_newline()
    end
    self.emitter:decrease_indent()

    self.emitter:emit_indented("end")
end

-- 打印字面量
function Printer:print_literal(node)
    if node.value == nil then
        self.emitter:emit("nil")
    elseif type(node.value) == "string" then
        self.emitter:emit(self.emitter:format_string(node.value))
    elseif type(node.value) == "number" then
        self.emitter:emit(self.emitter:format_number(node.value))
    elseif type(node.value) == "boolean" then
        self.emitter:emit(tostring(node.value))
    else
        self.emitter:emit(tostring(node.value))
    end
end

-- 打印标识符
function Printer:print_identifier(node)
    self.emitter:emit(self.emitter:format_identifier(node.name))
end

-- 打印二元表达式
function Printer:print_binary_expression(node)
    local left_needs_parens = self.formatter:needs_parentheses(node.left, node.operator)
    local right_needs_parens = self.formatter:needs_parentheses(node.right, node.operator)

    if left_needs_parens then
        self.emitter:emit("(")
    end
    self:print_node(node.left)
    if left_needs_parens then
        self.emitter:emit(")")
    end

    self.emitter:emit(" " .. node.operator .. " ")

    if right_needs_parens then
        self.emitter:emit("(")
    end
    self:print_node(node.right)
    if right_needs_parens then
        self.emitter:emit(")")
    end
end

-- 打印一元表达式
function Printer:print_unary_expression(node)
    self.emitter:emit(node.operator)
    if node.operator ~= "#" then
        self.emitter:emit(" ")
    end
    self:print_node(node.argument)
end

-- 打印赋值表达式
function Printer:print_assignment_expression(node)
    self:print_node(node.left)
    self.emitter:emit(" " .. node.operator .. " ")
    self:print_node(node.right)
end

-- 打印函数表达式
function Printer:print_function_expression(node)
    self.emitter:emit("function(")

    -- 打印参数
    for i, param in ipairs(node.params or {}) do
        self:print_node(param)
        if i < #node.params then
            self.emitter:emit(", ")
        end
    end

    self.emitter:emit(")")

    -- 打印函数体
    self.emitter:emit_newline()
    self.emitter:increase_indent()

    for _, stmt in ipairs(node.body or {}) do
        self.emitter:emit_indented("")
        self:print_node(stmt)
        self.emitter:emit_newline()
    end

    self.emitter:decrease_indent()
    self.emitter:emit_indented("end")
end

-- 打印函数调用表达式
function Printer:print_call_expression(node)
    self:print_node(node.base)
    self.emitter:emit("(")

    -- 打印参数
    for i, arg in ipairs(node.arguments or {}) do
        self:print_node(arg)
        if i < #node.arguments then
            self.emitter:emit(", ")
        end
    end

    self.emitter:emit(")")
end

-- 打印成员表达式
function Printer:print_member_expression(node)
    self:print_node(node.base)
    if node.computed then
        self.emitter:emit("[")
        self:print_node(node.identifier)
        self.emitter:emit("]")
    else
        self.emitter:emit(".")
        self:print_node(node.identifier)
    end
end

-- 打印表构造器
function Printer:print_table_constructor(node)
    self.emitter:emit("{")

    if node.fields and #node.fields > 0 then
        self.emitter:emit_newline()
        self.emitter:increase_indent()

        for i, field in ipairs(node.fields) do
            self.emitter:emit_indented("")
            self:print_node(field)

            if i < #node.fields then
                self.emitter:emit(",")
                self.emitter:emit_newline()
            end
        end

        self.emitter:emit_newline()
        self.emitter:decrease_indent()
        self.emitter:emit_indented("")
    end

    self.emitter:emit("}")
end

-- 打印表键值对（[key] = value）
function Printer:print_table_key(node)
    self.emitter:emit("[")
    self:print_node(node.key)
    self.emitter:emit("] = ")
    self:print_node(node.value)
end

-- 打印表键值对（key = value）
function Printer:print_table_key_string(node)
    self.emitter:emit(self.emitter:format_identifier(node.key))
    self.emitter:emit(" = ")
    self:print_node(node.value)
end

-- 打印表值（数组元素）
function Printer:print_table_value(node)
    self:print_node(node.value)
end

-- 打印 goto 语句
function Printer:print_goto_statement(node)
    self.emitter:emit("goto " .. node.label)
end

-- 打印 label 语句
function Printer:print_label_statement(node)
    self.emitter:emit("::" .. node.name .. "::")
end

-- 打印未知节点类型
function Printer:print_unknown_node(node)
    self.emitter:emit("--[[ Unknown node type: " .. node.type .. " ]]")
end

return M

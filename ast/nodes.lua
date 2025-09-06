-- AST 节点构造函数

local M = {}

-- 节点类型常量
M.NodeType = {
    -- 程序
    PROGRAM = "Program",
    
    -- 语句
    EXPRESSION_STATEMENT = "ExpressionStatement",
    LOCAL_STATEMENT = "LocalStatement",
    ASSIGNMENT_STATEMENT = "AssignmentStatement",
    FUNCTION_DECLARATION = "FunctionDeclaration",
    IF_STATEMENT = "IfStatement",
    WHILE_STATEMENT = "WhileStatement",
    REPEAT_STATEMENT = "RepeatStatement",
    FOR_NUMERIC_STATEMENT = "ForNumericStatement",
    FOR_GENERIC_STATEMENT = "ForGenericStatement",
    RETURN_STATEMENT = "ReturnStatement",
    BREAK_STATEMENT = "BreakStatement",
    GOTO_STATEMENT = "GotoStatement",
    LABEL_STATEMENT = "LabelStatement",
    DO_STATEMENT = "DoStatement",
    
    -- 表达式
    LITERAL = "Literal",
    IDENTIFIER = "Identifier",
    BINARY_EXPRESSION = "BinaryExpression",
    UNARY_EXPRESSION = "UnaryExpression",
    ASSIGNMENT_EXPRESSION = "AssignmentExpression",
    FUNCTION_EXPRESSION = "FunctionExpression",
    CALL_EXPRESSION = "CallExpression",
    MEMBER_EXPRESSION = "MemberExpression",
    TABLE_CONSTRUCTOR = "TableConstructor",
    
    -- 表构造
    TABLE_KEY = "TableKey",
    TABLE_KEY_STRING = "TableKeyString",
    TABLE_VALUE = "TableValue",
    
    -- 控制流子句
    IF_CLAUSE = "IfClause",
    ELSEIF_CLAUSE = "ElseifClause",
    ELSE_CLAUSE = "ElseClause"
}

-- 创建基础节点
function M.create_node(type, loc, range, extra_fields)
    local node = {
        type = type,
        loc = loc,
        range = range
    }
    
    if extra_fields then
        for key, value in pairs(extra_fields) do
            node[key] = value
        end
    end
    
    return node
end

-- 程序节点
function M.create_program(body, loc, range)
    return M.create_node(M.NodeType.PROGRAM, loc, range, {
        body = body or {}
    })
end

-- 字面量节点
function M.create_literal(value, raw, loc, range)
    return M.create_node(M.NodeType.LITERAL, loc, range, {
        value = value,
        raw = raw
    })
end

-- 标识符节点
function M.create_identifier(name, loc, range)
    return M.create_node(M.NodeType.IDENTIFIER, loc, range, {
        name = name
    })
end

-- 二元表达式节点
function M.create_binary_expression(operator, left, right, loc, range)
    return M.create_node(M.NodeType.BINARY_EXPRESSION, loc, range, {
        operator = operator,
        left = left,
        right = right
    })
end

-- 一元表达式节点
function M.create_unary_expression(operator, argument, prefix, loc, range)
    return M.create_node(M.NodeType.UNARY_EXPRESSION, loc, range, {
        operator = operator,
        argument = argument,
        prefix = prefix or true
    })
end

-- 赋值表达式节点
function M.create_assignment_expression(operator, left, right, loc, range)
    return M.create_node(M.NodeType.ASSIGNMENT_EXPRESSION, loc, range, {
        operator = operator,
        left = left,
        right = right
    })
end

-- 函数表达式节点
function M.create_function_expression(params, body, is_local, loc, range)
    return M.create_node(M.NodeType.FUNCTION_EXPRESSION, loc, range, {
        params = params or {},
        body = body or {},
        isLocal = is_local or false
    })
end

-- 调用表达式节点
function M.create_call_expression(base, arguments, loc, range)
    return M.create_node(M.NodeType.CALL_EXPRESSION, loc, range, {
        base = base,
        arguments = arguments or {}
    })
end

-- 成员表达式节点
function M.create_member_expression(base, identifier, computed, loc, range)
    return M.create_node(M.NodeType.MEMBER_EXPRESSION, loc, range, {
        base = base,
        identifier = identifier,
        computed = computed or false
    })
end

-- 表构造节点
function M.create_table_constructor(fields, loc, range)
    return M.create_node(M.NodeType.TABLE_CONSTRUCTOR, loc, range, {
        fields = fields or {}
    })
end

-- 表键节点（[key] = value）
function M.create_table_key(key, value, loc, range)
    return M.create_node(M.NodeType.TABLE_KEY, loc, range, {
        key = key,
        value = value
    })
end

-- 表键字符串节点（key = value）
function M.create_table_key_string(key, value, loc, range)
    return M.create_node(M.NodeType.TABLE_KEY_STRING, loc, range, {
        key = key,
        value = value
    })
end

-- 表值节点（数组元素）
function M.create_table_value(value, loc, range)
    return M.create_node(M.NodeType.TABLE_VALUE, loc, range, {
        value = value
    })
end

-- 表达式语句节点
function M.create_expression_statement(expression, loc, range)
    return M.create_node(M.NodeType.EXPRESSION_STATEMENT, loc, range, {
        expression = expression
    })
end

-- 本地语句节点
function M.create_local_statement(variables, init, loc, range)
    return M.create_node(M.NodeType.LOCAL_STATEMENT, loc, range, {
        variables = variables or {},
        init = init or {}
    })
end

-- 赋值语句节点
function M.create_assignment_statement(variables, init, loc, range)
    return M.create_node(M.NodeType.ASSIGNMENT_STATEMENT, loc, range, {
        variables = variables or {},
        init = init or {}
    })
end

-- 函数声明节点
function M.create_function_declaration(identifier, params, body, is_local, loc, range)
    return M.create_node(M.NodeType.FUNCTION_DECLARATION, loc, range, {
        identifier = identifier,
        params = params or {},
        body = body or {},
        isLocal = is_local or false
    })
end

-- if 语句节点
function M.create_if_statement(clauses, loc, range)
    return M.create_node(M.NodeType.IF_STATEMENT, loc, range, {
        clauses = clauses or {}
    })
end

-- if 子句节点
function M.create_if_clause(condition, body, loc, range)
    return M.create_node(M.NodeType.IF_CLAUSE, loc, range, {
        condition = condition,
        body = body or {}
    })
end

-- elseif 子句节点
function M.create_elseif_clause(condition, body, loc, range)
    return M.create_node(M.NodeType.ELSEIF_CLAUSE, loc, range, {
        condition = condition,
        body = body or {}
    })
end

-- else 子句节点
function M.create_else_clause(body, loc, range)
    return M.create_node(M.NodeType.ELSE_CLAUSE, loc, range, {
        body = body or {}
    })
end

-- while 语句节点
function M.create_while_statement(condition, body, loc, range)
    return M.create_node(M.NodeType.WHILE_STATEMENT, loc, range, {
        condition = condition,
        body = body or {}
    })
end

-- repeat 语句节点
function M.create_repeat_statement(condition, body, loc, range)
    return M.create_node(M.NodeType.REPEAT_STATEMENT, loc, range, {
        condition = condition,
        body = body or {}
    })
end

-- 数值 for 语句节点
function M.create_for_numeric_statement(variable, start, stop, step, body, loc, range)
    return M.create_node(M.NodeType.FOR_NUMERIC_STATEMENT, loc, range, {
        variable = variable,
        start = start,
        ["end"] = stop,  -- end 是 Lua 关键字，需要用引号
        step = step,
        body = body or {}
    })
end

-- 泛型 for 语句节点
function M.create_for_generic_statement(variables, iterators, body, loc, range)
    return M.create_node(M.NodeType.FOR_GENERIC_STATEMENT, loc, range, {
        variables = variables or {},
        iterators = iterators or {},
        body = body or {}
    })
end

-- return 语句节点
function M.create_return_statement(arguments, loc, range)
    return M.create_node(M.NodeType.RETURN_STATEMENT, loc, range, {
        arguments = arguments or {}
    })
end

-- break 语句节点
function M.create_break_statement(loc, range)
    return M.create_node(M.NodeType.BREAK_STATEMENT, loc, range, {})
end

-- goto 语句节点
function M.create_goto_statement(label, loc, range)
    return M.create_node(M.NodeType.GOTO_STATEMENT, loc, range, { label = label })
end

-- label 语句节点
function M.create_label_statement(name, loc, range)
    return M.create_node(M.NodeType.LABEL_STATEMENT, loc, range, { name = name })
end

-- do 语句节点
function M.create_do_statement(body, loc, range)
    return M.create_node(M.NodeType.DO_STATEMENT, loc, range, {
        body = body or {}
    })
end

-- 节点工厂方法（简化调用）
M.NodeFactory = {}

-- 根据类型创建节点的工厂方法
function M.NodeFactory.create(type, ...)
    local factory_methods = {
        [M.NodeType.PROGRAM] = M.create_program,
        [M.NodeType.LITERAL] = M.create_literal,
        [M.NodeType.IDENTIFIER] = M.create_identifier,
        [M.NodeType.BINARY_EXPRESSION] = M.create_binary_expression,
        [M.NodeType.UNARY_EXPRESSION] = M.create_unary_expression,
        [M.NodeType.ASSIGNMENT_EXPRESSION] = M.create_assignment_expression,
        [M.NodeType.FUNCTION_EXPRESSION] = M.create_function_expression,
        [M.NodeType.CALL_EXPRESSION] = M.create_call_expression,
        [M.NodeType.MEMBER_EXPRESSION] = M.create_member_expression,
        [M.NodeType.TABLE_CONSTRUCTOR] = M.create_table_constructor,
        [M.NodeType.TABLE_KEY] = M.create_table_key,
        [M.NodeType.TABLE_KEY_STRING] = M.create_table_key_string,
        [M.NodeType.TABLE_VALUE] = M.create_table_value,
        [M.NodeType.EXPRESSION_STATEMENT] = M.create_expression_statement,
        [M.NodeType.LOCAL_STATEMENT] = M.create_local_statement,
        [M.NodeType.ASSIGNMENT_STATEMENT] = M.create_assignment_statement,
        [M.NodeType.FUNCTION_DECLARATION] = M.create_function_declaration,
        [M.NodeType.IF_STATEMENT] = M.create_if_statement,
        [M.NodeType.IF_CLAUSE] = M.create_if_clause,
        [M.NodeType.ELSEIF_CLAUSE] = M.create_elseif_clause,
        [M.NodeType.ELSE_CLAUSE] = M.create_else_clause,
        [M.NodeType.WHILE_STATEMENT] = M.create_while_statement,
        [M.NodeType.REPEAT_STATEMENT] = M.create_repeat_statement,
        [M.NodeType.FOR_NUMERIC_STATEMENT] = M.create_for_numeric_statement,
        [M.NodeType.FOR_GENERIC_STATEMENT] = M.create_for_generic_statement,
        [M.NodeType.RETURN_STATEMENT] = M.create_return_statement,
        [M.NodeType.BREAK_STATEMENT] = M.create_break_statement,
        [M.NodeType.GOTO_STATEMENT] = M.create_goto_statement,
        [M.NodeType.LABEL_STATEMENT] = M.create_label_statement,
        [M.NodeType.DO_STATEMENT] = M.create_do_statement
    }
    
    local factory_method = factory_methods[type]
    if factory_method then
        return factory_method(...)
    else
        error("Unknown node type: " .. type)
    end
end

return M

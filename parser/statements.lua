-- 语句解析器

local M = {}

-- 导入依赖
local ast = require("lua.ast")

-- 语句解析器类
local StatementParser = {}
StatementParser.__index = StatementParser

-- 创建语句解析器
function M.create(parser)
    local self = setmetatable({}, StatementParser)
    self.parser = parser  -- 引用主解析器
    return self
end

-- 解析语句
function StatementParser:parse_statement()
    local token = self.parser:peek()

    if not token then
        return nil
    end

    -- 根据语句类型分发
    if token.type == "LOCAL" then
        return self:parse_local_statement()
    elseif token.type == "IF" then
        return self:parse_if_statement()
    elseif token.type == "WHILE" then
        return self:parse_while_statement()
    elseif token.type == "REPEAT" then
        return self:parse_repeat_statement()
    elseif token.type == "FOR" then
        return self:parse_for_statement()
    elseif token.type == "FUNCTION" then
        return self:parse_function_declaration()
    elseif token.type == "RETURN" then
        return self:parse_return_statement()
    elseif token.type == "BREAK" then
        return self:parse_break_statement()
    elseif token.type == "DO" then
        return self:parse_do_statement()
    elseif token.type == "GOTO" then
        return self:parse_goto_statement()
    elseif token.type == "COLON_COLON" then
        return self:parse_label_statement()
    elseif token.type == "IDENTIFIER" then
        -- 可能是赋值语句或函数调用语句
        return self:parse_assignment_or_call_statement()
    else
        -- 表达式语句
        return self:parse_expression_statement()
    end
end

-- 解析本地语句 (local x = 1, y = 2)
function StatementParser:parse_local_statement()
    local start_token = self.parser:peek()
    self.parser:advance()  -- 消耗 'local'

    -- 解析变量列表
    local variables = {}
    local init = {}

    -- 检查是否是 local function
    if self.parser:check("FUNCTION") then
        -- 这是 local function 声明，转交给函数声明解析器
        return self:parse_local_function_declaration()
    end

    -- 至少要有一个变量
    if not self.parser:check("IDENTIFIER") then
        self.parser:add_error("Expected identifier or 'function' after 'local'", self.parser:peek().loc)
        return nil
    end

    -- 解析变量名
    while true do
        if not self.parser:check("IDENTIFIER") then
            break
        end

        local var_token = self.parser:peek()
        self.parser:advance()

        local variable = ast.create_identifier(var_token.value, var_token.loc, var_token.range)
        table.insert(variables, variable)

        if not self.parser:check("COMMA") then
            break
        end
        self.parser:advance()  -- 消耗逗号
    end

    -- 解析初始化表达式（可选）
    if self.parser:check("EQUAL") then
        self.parser:advance()  -- 消耗 '='

        -- 解析初始化表达式列表
        while true do
            local expr = self.parser.expression_parser:parse_expression()
            if expr then
                table.insert(init, expr)
            end

            if not self.parser:check("COMMA") then
                break
            end
            self.parser:advance()  -- 消耗逗号
        end
    end

    local span = self.parser:create_span(start_token.loc.start, self.parser:previous().loc["end"])
    return ast.create_local_statement(variables, init, span.loc, span.range)
end

-- 解析赋值语句或函数调用语句
function StatementParser:parse_assignment_or_call_statement()
    local start_token = self.parser:peek()

    -- 解析左侧变量列表（支持成员表达式）
    local variables = {}

    while true do
        local var = self:parse_variable()
        if not var then
            break
        end
        table.insert(variables, var)

        if not self.parser:check("COMMA") then
            break
        end
        self.parser:advance()  -- 消耗逗号
    end

    -- 检查是否有 '='（赋值语句）
    if self.parser:check("EQUAL") then
        -- 这是赋值语句
        self.parser:advance()  -- 消耗 '='

        local init = {}

        -- 解析右侧表达式列表
        while true do
            local expr = self.parser.expression_parser:parse_expression()
            if expr then
                table.insert(init, expr)
            end

            if not self.parser:check("COMMA") then
                break
            end
            self.parser:advance()  -- 消耗逗号
        end

        local span = self.parser:create_span(start_token.loc.start, self.parser:previous().loc["end"])
        return ast.create_assignment_statement(variables, init, span.loc, span.range)

    -- 检查是否是函数调用（如果是单个变量后跟左括号）
    elseif #variables == 1 and self.parser:check("LEFT_PAREN") then
        -- 这是一个函数调用语句
        local base_expr = variables[1]
        self.parser:advance()  -- 消耗 '('
        local arguments = {}

        -- 解析参数
        if not self.parser:check("RIGHT_PAREN") then
            while true do
                local arg = self.parser.expression_parser:parse_expression()
                if arg then
                    table.insert(arguments, arg)
                end

                if not self.parser:check("COMMA") then
                    break
                end
                self.parser:advance()  -- 消耗逗号
            end
        end

        if not self.parser:expect("RIGHT_PAREN") then
            return nil
        end

        local end_loc = self.parser:previous().loc["end"]
        local span = self.parser:create_span(base_expr.loc.start, end_loc)

        local call_expr = ast.create_call_expression(base_expr, arguments, span.loc, span.range)
        local stmt_span = self.parser:create_span(start_token.loc.start, call_expr.loc["end"])
        return ast.create_expression_statement(call_expr, stmt_span.loc, stmt_span.range)

    else
        -- 如果只有一个变量且后面没有其他内容，这可能是表达式语句
        if #variables == 1 and not self.parser:check("COMMA") then
            local span = self.parser:create_span(start_token.loc.start, variables[1].loc["end"])
            return ast.create_expression_statement(variables[1], span.loc, span.range)
        else
            -- 既不是赋值也不是函数调用，当作表达式语句处理
            self.parser:add_error("Expected '=' or '(' after variable", start_token.loc)
            return nil
        end
    end
end

-- 解析局部函数声明
function StatementParser:parse_local_function_declaration()
    local start_token = self.parser:peek()
    self.parser:advance()  -- 消耗 'function' (local 已经被消耗)

    -- 解析函数名（支持成员函数）
    if not self.parser:check("IDENTIFIER") then
        self.parser:add_error("Expected function name after 'local function'", self.parser:peek().loc)
        return nil
    end

    local func_name_token = self.parser:peek()
    self.parser:advance()

    local func_name = ast.create_identifier(func_name_token.value, func_name_token.loc, func_name_token.range)

    -- 处理成员函数 (table.function_name)
    while self.parser:check("DOT") do
        self.parser:advance()  -- 消耗 '.'

        if not self.parser:check("IDENTIFIER") then
            self.parser:add_error("Expected identifier after '.' in local function name", self.parser:peek().loc)
            return nil
        end

        local member_token = self.parser:peek()
        self.parser:advance()

        local member_name = ast.create_identifier(member_token.value, member_token.loc, member_token.range)
        local span = self.parser:create_span(func_name.loc.start, member_token.loc["end"])

        func_name = ast.create_member_expression(func_name, member_name, false, span.loc, span.range)
    end

    -- 解析参数列表
    if not self.parser:expect("LEFT_PAREN") then
        return nil
    end

    local params = {}
    if not self.parser:check("RIGHT_PAREN") then
        while true do
            if not self.parser:check("IDENTIFIER") then
                self.parser:add_error("Expected parameter name", self.parser:peek().loc)
                return nil
            end

            local param_token = self.parser:peek()
            self.parser:advance()

            local param = ast.create_identifier(param_token.value, param_token.loc, param_token.range)
            table.insert(params, param)

            if not self.parser:check("COMMA") then
                break
            end
            self.parser:advance()  -- 消耗逗号
        end
    end

    if not self.parser:expect("RIGHT_PAREN") then
        return nil
    end

    -- 解析函数体
    local body = self:parse_function_body()

    if not body then
        return nil
    end

    -- 创建局部函数声明
    local span = self.parser:create_span(start_token.loc.start, self.parser:previous().loc["end"])
    return ast.create_function_declaration(func_name, params, body, true, span.loc, span.range)
end

-- 解析函数体（语句块）
function StatementParser:parse_function_body()
    local statements = {}

    while not self.parser:check("END") and not self.parser:is_at_end() do
        local stmt = self:parse_statement()
        if stmt then
            table.insert(statements, stmt)
        end
    end

    if not self.parser:expect("END") then
        return nil
    end

    return statements
end

-- 解析变量（支持 a.b, a[b] 等形式）
function StatementParser:parse_variable()
    -- 检查当前token是否是标识符
    local token = self.parser:peek()
    if token and token.type == "IDENTIFIER" then
        -- 消耗标识符并创建基本变量
        self.parser:advance()
        local base = ast.create_identifier(token.value, token.loc, token.range)

        -- 处理成员访问 (a.b 或 a[b] 或 a:b)
        while self.parser:check("DOT") or self.parser:check("LEFT_BRACKET") or self.parser:check("COLON") do
            if self.parser:check("DOT") then
                self.parser:advance()  -- 消耗 '.'

                if not self.parser:check("IDENTIFIER") then
                    self.parser:add_error("Expected identifier after '.'", self.parser:peek().loc)
                    break
                end

                local prop_token = self.parser:peek()
                self.parser:advance()

                local property = ast.create_identifier(prop_token.value, prop_token.loc, prop_token.range)
                local span = self.parser:create_span(base.loc.start, prop_token.loc["end"])

                base = ast.create_member_expression(base, property, false, span.loc, span.range)

            elseif self.parser:check("LEFT_BRACKET") then
                self.parser:advance()  -- 消耗 '['

                local property = self.parser.expression_parser:parse_expression()

                if not self.parser:expect("RIGHT_BRACKET") then
                    return base
                end

                local end_loc = self.parser:previous().loc["end"]
                local span = self.parser:create_span(base.loc.start, end_loc)

                base = ast.create_member_expression(base, property, true, span.loc, span.range)

            elseif self.parser:check("COLON") then
                -- 处理方法调用语法糖 (obj:method)
                self.parser:advance()  -- 消耗 ':'
                if not self.parser:check("IDENTIFIER") then
                    self.parser:add_error("Expected identifier after ':'", self.parser:peek().loc)
                    break
                end
                local method_token = self.parser:peek()
                self.parser:advance()
                local method = ast.create_identifier(method_token.value, method_token.loc, method_token.range)
                local span = self.parser:create_span(base.loc.start, method_token.loc["end"])
                base = ast.create_member_expression(base, method, false, span.loc, span.range)
                base.is_method_call = true  -- 标记为方法调用
            end
        end

        return base
    else
        -- 不是标识符，返回nil
        return nil
    end
end

-- 解析 if 语句
function StatementParser:parse_if_statement()
    local start_token = self.parser:peek()
    self.parser:advance()  -- 消耗 'if'

    -- 解析条件
    local condition = self.parser.expression_parser:parse_expression()

    if not self.parser:expect("THEN") then
        return nil
    end

    -- 解析 then 分支
    local then_body = self:parse_statement_block()

    local clauses = {
        ast.create_if_clause(condition, then_body, condition.loc, {condition.range[1], then_body and then_body[#then_body] and then_body[#then_body].range[2] or condition.range[2]})
    }

    -- 解析 elseif 分支
    while self.parser:check("ELSEIF") do
        self.parser:advance()  -- 消耗 'elseif'

        local elseif_condition = self.parser.expression_parser:parse_expression()

        if not self.parser:expect("THEN") then
            break
        end

        local elseif_body = self:parse_statement_block()

        table.insert(clauses, ast.create_elseif_clause(elseif_condition, elseif_body,
            elseif_condition.loc, {elseif_condition.range[1], elseif_body and elseif_body[#elseif_body] and elseif_body[#elseif_body].range[2] or elseif_condition.range[2]}))
    end

    -- 解析 else 分支
    if self.parser:check("ELSE") then
        self.parser:advance()  -- 消耗 'else'

        local else_body = self:parse_statement_block()

        table.insert(clauses, ast.create_else_clause(else_body,
            else_body and else_body[1] and else_body[1].loc or start_token.loc,
            else_body and else_body[#else_body] and {else_body[1].range[1], else_body[#else_body].range[2]} or {0,0}))
    end

    if not self.parser:expect("END") then
        return nil
    end

    local span = self.parser:create_span(start_token.loc.start, self.parser:previous().loc["end"])
    return ast.create_if_statement(clauses, span.loc, span.range)
end

-- 解析 while 语句
function StatementParser:parse_while_statement()
    local start_token = self.parser:peek()
    self.parser:advance()  -- 消耗 'while'

    local condition = self.parser.expression_parser:parse_expression()

    if not self.parser:expect("DO") then
        return nil
    end

    local body = self:parse_statement_block()

    if not self.parser:expect("END") then
        return nil
    end

    local span = self.parser:create_span(start_token.loc.start, self.parser:previous().loc["end"])
    return ast.create_while_statement(condition, body, span.loc, span.range)
end

-- 解析 repeat 语句
function StatementParser:parse_repeat_statement()
    local start_token = self.parser:peek()
    self.parser:advance()  -- 消耗 'repeat'

    local body = self:parse_statement_block()

    if not self.parser:expect("UNTIL") then
        return nil
    end

    local condition = self.parser.expression_parser:parse_expression()

    local span = self.parser:create_span(start_token.loc.start, condition.loc["end"])
    return ast.create_repeat_statement(condition, body, span.loc, span.range)
end

-- 解析 for 语句
function StatementParser:parse_for_statement()
    local start_token = self.parser:peek()
    self.parser:advance()  -- 消耗 'for'

    -- 解析变量列表
    local variables = {}

    -- 解析第一个变量
    if not self.parser:check("IDENTIFIER") then
        self.parser:add_error("Expected identifier in for loop", self.parser:peek().loc)
        return nil
    end

    local var_token = self.parser:peek()
    self.parser:advance()
    local variable = ast.create_identifier(var_token.value, var_token.loc, var_token.range)
    table.insert(variables, variable)

    -- 解析其他变量（用逗号分隔）
    while self.parser:check("COMMA") do
        self.parser:advance()  -- 消耗逗号

        if not self.parser:check("IDENTIFIER") then
            self.parser:add_error("Expected identifier after ',' in for loop", self.parser:peek().loc)
            return nil
        end

        var_token = self.parser:peek()
        self.parser:advance()
        variable = ast.create_identifier(var_token.value, var_token.loc, var_token.range)
        table.insert(variables, variable)
    end

    if self.parser:check("EQUAL") then
        -- 数值 for 循环: for i = start, stop, step do
        self.parser:advance()  -- 消耗 '='

        local start_expr = self.parser.expression_parser:parse_expression()

        if not self.parser:expect("COMMA") then
            return nil
        end

        local stop_expr = self.parser.expression_parser:parse_expression()

        local step_expr = nil
        if self.parser:check("COMMA") then
            self.parser:advance()  -- 消耗逗号
            step_expr = self.parser.expression_parser:parse_expression()
        end

        if not self.parser:expect("DO") then
            return nil
        end

        local body = self:parse_statement_block()

        if not self.parser:expect("END") then
            return nil
        end

        local span = self.parser:create_span(start_token.loc.start, self.parser:previous().loc["end"])
        return ast.create_for_numeric_statement(variables[1], start_expr, stop_expr, step_expr, body, span.loc, span.range)

    elseif self.parser:check("IN") then
        -- 泛型 for 循环: for k, v in iterator do
        self.parser:advance()  -- 消耗 'in'

        local iterators = {}

        -- 解析迭代器表达式列表
        while true do
            local iter = self.parser.expression_parser:parse_expression()
            if iter then
                table.insert(iterators, iter)
            end

            if not self.parser:check("COMMA") then
                break
            end
            self.parser:advance()  -- 消耗逗号
        end

        if not self.parser:expect("DO") then
            return nil
        end

        local body = self:parse_statement_block()

        if not self.parser:expect("END") then
            return nil
        end

        local span = self.parser:create_span(start_token.loc.start, self.parser:previous().loc["end"])
        return ast.create_for_generic_statement(variables, iterators, body, span.loc, span.range)

    else
        self.parser:add_error("Expected '=' or 'in' in for loop", self.parser:peek().loc)
        return nil
    end
end

-- 解析函数声明
function StatementParser:parse_function_declaration()
    local start_token = self.parser:peek()
    self.parser:advance()  -- 消耗 'function'

    -- 解析函数名（支持成员函数）
    if not self.parser:check("IDENTIFIER") then
        self.parser:add_error("Expected function name", self.parser:peek().loc)
        return nil
    end

    local name_token = self.parser:peek()
    self.parser:advance()

    local function_name = ast.create_identifier(name_token.value, name_token.loc, name_token.range)

    -- 处理成员函数 (table.function_name)
    while self.parser:check("DOT") do
        self.parser:advance()  -- 消耗 '.'

        if not self.parser:check("IDENTIFIER") then
            self.parser:add_error("Expected identifier after '.' in function name", self.parser:peek().loc)
            return nil
        end

        local member_token = self.parser:peek()
        self.parser:advance()

        local member_name = ast.create_identifier(member_token.value, member_token.loc, member_token.range)
        local span = self.parser:create_span(function_name.loc.start, member_token.loc["end"])

        function_name = ast.create_member_expression(function_name, member_name, false, span.loc, span.range)
    end

    -- 解析参数列表
    if not self.parser:expect("LEFT_PAREN") then
        return nil
    end

    local params = {}

    if not self.parser:check("RIGHT_PAREN") then
        -- 解析参数
        while true do
            if not self.parser:check("IDENTIFIER") then
                break
            end

            local param_token = self.parser:peek()
            self.parser:advance()

            local param = ast.create_identifier(param_token.value, param_token.loc, param_token.range)
            table.insert(params, param)

            if not self.parser:check("COMMA") then
                break
            end
            self.parser:advance()  -- 消耗逗号
        end
    end

    if not self.parser:expect("RIGHT_PAREN") then
        return nil
    end

    -- 解析函数体
    local body = self:parse_statement_block()

    if not self.parser:expect("END") then
        return nil
    end

    local span = self.parser:create_span(start_token.loc.start, self.parser:previous().loc["end"])
    return ast.create_function_declaration(function_name, params, body, false, span.loc, span.range)
end

-- 解析 return 语句
function StatementParser:parse_return_statement()
    local start_token = self.parser:peek()
    self.parser:advance()  -- 消耗 'return'

    local arguments = {}

    -- 解析返回值列表（可选）
    if not self.parser:check("END") and not self.parser:check("ELSE") and not self.parser:check("ELSEIF") then
        while true do
            local expr = self.parser.expression_parser:parse_expression()
            if expr then
                table.insert(arguments, expr)
            end

            if not self.parser:check("COMMA") then
                break
            end
            self.parser:advance()  -- 消耗逗号
        end
    end

    local span = self.parser:create_span(start_token.loc.start, self.parser:previous().loc["end"])
    return ast.create_return_statement(arguments, span.loc, span.range)
end

-- 解析 break 语句
function StatementParser:parse_break_statement()
    local token = self.parser:peek()
    self.parser:advance()  -- 消耗 'break'

    return ast.create_break_statement(token.loc, token.range)
end

-- 解析 do 语句
function StatementParser:parse_do_statement()
    local start_token = self.parser:peek()
    self.parser:advance()  -- 消耗 'do'

    local body = self:parse_statement_block()

    if not self.parser:expect("END") then
        return nil
    end

    local span = self.parser:create_span(start_token.loc.start, self.parser:previous().loc["end"])
    return ast.create_do_statement(body, span.loc, span.range)
end

-- 解析表达式语句
function StatementParser:parse_expression_statement()
    local expr = self.parser.expression_parser:parse_expression()

    if not expr then
        return nil
    end

    local span = self.parser:create_span(expr.loc.start, expr.loc["end"])
    return ast.create_expression_statement(expr, span.loc, span.range)
end

-- 解析语句块
function StatementParser:parse_statement_block()
    local statements = {}

    while not self.parser:check("END") and
          not self.parser:check("ELSE") and
          not self.parser:check("ELSEIF") and
          not self.parser:check("UNTIL") and
          not self.parser:is_at_end() do

        local stmt = self:parse_statement()
        if stmt then
            table.insert(statements, stmt)
        end

        -- 跳过分号（可选）
        if self.parser:check("SEMICOLON") then
            self.parser:advance()
        end
    end

    return statements
end

-- 解析goto语句
function StatementParser:parse_goto_statement()
    -- 消耗 goto 关键字
    local goto_token = self.parser:peek()
    self.parser:advance()

    -- 期望标签名
    if not self.parser:check("IDENTIFIER") then
        self.parser:add_error("Expected identifier after 'goto'", self.parser:peek().loc)
        return ast.create_goto_statement("", goto_token.loc, {goto_token.range[1], goto_token.range[2]})
    end

    local label_token = self.parser:peek()
    self.parser:advance()

    -- 可选的分号
    if self.parser:check("SEMICOLON") then
        self.parser:advance()
    end

    local span = self.parser:create_span(goto_token.loc.start, label_token.loc["end"])
    return ast.create_goto_statement(label_token.value, span.loc, span.range)
end

-- 解析标签语句
function StatementParser:parse_label_statement()
    -- 消耗 :: token
    local colon_token = self.parser:peek()
    self.parser:advance()

    -- 期望标签名
    if not self.parser:check("IDENTIFIER") then
        self.parser:add_error("Expected identifier in label statement", self.parser:peek().loc)
        return ast.create_label_statement("", colon_token.loc, {colon_token.range[1], colon_token.range[2]})
    end

    local label_token = self.parser:peek()
    self.parser:advance()

    -- 期望第二个 :: token
    if not self.parser:check("COLON_COLON") then
        self.parser:add_error("Expected '::' after label name", self.parser:peek().loc)
        return ast.create_label_statement(label_token.value, colon_token.loc, {colon_token.range[1], label_token.range[2]})
    end

    self.parser:advance()

    local span = self.parser:create_span(colon_token.loc.start, self.parser:previous().loc["end"])
    return ast.create_label_statement(label_token.value, span.loc, span.range)
end

return M

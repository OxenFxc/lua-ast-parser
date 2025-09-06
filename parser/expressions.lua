-- 表达式解析器

local M = {}

-- 导入依赖
local ast = require("lua.ast")
local precedence = require("lua.parser.precedence")

-- 表达式解析器类
local ExpressionParser = {}
ExpressionParser.__index = ExpressionParser

-- 创建表达式解析器
function M.create(parser)
    local self = setmetatable({}, ExpressionParser)
    self.parser = parser  -- 引用主解析器
    return self
end

-- 解析表达式
function ExpressionParser:parse_expression()
    return self:parse_binary_expression(0)
end

-- 解析二元表达式（使用优先级爬升算法）
function ExpressionParser:parse_binary_expression(min_precedence)
    -- 解析左侧操作数（可能是更高优先级的表达式）
    local left = self:parse_unary_expression()

    while true do
        local token = self.parser:peek()
        if not token then break end

        -- 检查是否为二元运算符
        if not precedence.is_binary_operator(token.value) then
            break
        end

        local operator = token.value
        local op_precedence = precedence.get_precedence(operator)

        -- 如果当前运算符优先级低于最小优先级，停止
        if op_precedence < min_precedence then
            break
        end

        -- 消耗运算符
        self.parser:advance()

        -- 根据结合性计算下一个最小优先级
        local associativity = precedence.get_associativity(operator)
        local next_min_precedence
        if associativity == precedence.ASSOCIATIVITY.LEFT then
            next_min_precedence = op_precedence + 1
        else
            next_min_precedence = op_precedence
        end

        -- 解析右侧操作数
        local right = self:parse_binary_expression(next_min_precedence)

        -- 创建二元表达式节点
        if left and right and left.loc and right.loc then
            local span = self.parser:create_span(left.loc.start, right.loc["end"])
            left = ast.create_binary_expression(operator, left, right, span.loc, span.range)
        else
            -- 如果解析失败，返回nil
            return nil
        end
    end

    return left
end

-- 解析一元表达式
function ExpressionParser:parse_unary_expression()
    local token = self.parser:peek()

    -- 检查是否为一元运算符
    if precedence.is_unary_operator(token.value) then
        self.parser:advance()
        local operator = token.value

        -- 解析操作数
        local argument = self:parse_unary_expression()

        -- 创建一元表达式节点
        if argument and argument.loc then
            local span = self.parser:create_span(token.loc.start, argument.loc["end"])
            return ast.create_unary_expression(operator, argument, true, span.loc, span.range)
        end

        -- 如果解析失败，返回nil
        return nil
    end

    -- 解析基本表达式
    return self:parse_primary_expression()
end

-- 解析基本表达式（原子表达式）
function ExpressionParser:parse_primary_expression()
    local token = self.parser:peek()


    if not token then
        self.parser:add_error("Unexpected end of input", self.parser.last_location or {start={line=1,column=1}, ["end"]={line=1,column=1}})
        return nil
    end

    -- 字面量
    if token.type == "NUMBER" or token.type == "STRING" or token.type == "BOOLEAN" or token.type == "NIL" then
        self.parser:advance()
        local value

        if token.type == "NUMBER" then
            value = tonumber(token.value)
        elseif token.type == "BOOLEAN" then
            value = (token.value == "true")
        elseif token.type == "NIL" then
            value = nil
        else
            value = token.value
        end

        return ast.create_literal(value, token.value, token.loc, token.range)
    end

    -- 标识符或函数调用
    if token.type == "IDENTIFIER" then
        -- 检查是否是函数调用
        if self.parser:peek(1) and self.parser:peek(1).type == "LEFT_PAREN" then
            -- 是函数调用，消耗标识符并解析调用
            self.parser:advance()  -- 消耗函数名
            return self:parse_call_expression_from_identifier(token)
        else
            -- 普通标识符，消耗并处理成员访问
            self.parser:advance()
            local base = ast.create_identifier(token.value, token.loc, token.range)

            -- 处理成员访问 (a.b 或 a[b])
            while self.parser:check("DOT") or self.parser:check("LEFT_BRACKET") do
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

                    local property = self:parse_expression()

                    if not self.parser:expect("RIGHT_BRACKET") then
                        return base
                    end

                    local end_loc = self.parser:previous().loc["end"]
                    local span = self.parser:create_span(base.loc.start, end_loc)

                    base = ast.create_member_expression(base, property, true, span.loc, span.range)
                end
            end

            -- 检查是否是函数调用
            if self.parser:check("LEFT_PAREN") then
                -- 这是一个函数调用，消耗'('并解析调用
                self.parser:advance()  -- 消耗 '('

                -- 解析参数列表
                local arguments = {}
                local start_loc = base.loc.start

                if not self.parser:check("RIGHT_PAREN") then
                    -- 解析参数
                    while true do
                        local arg = self:parse_expression()
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

                -- 处理方法调用语法糖
                if base.is_method_call then
                    -- 对于方法调用 obj:method()，自动添加obj作为第一个参数
                    table.insert(arguments, 1, base.base)
                    local method_call = ast.create_call_expression(
                        ast.create_member_expression(base.base, base.identifier, false, base.loc, base.range),
                        arguments, base.loc, {base.range[1], self.parser:previous().loc["end"] and self.parser:position_to_offset(self.parser:previous().loc["end"]) or base.range[2]}
                    )
                    return method_call
                else
                    -- 普通函数调用
                    local end_loc = self.parser:previous().loc["end"]
                    local span = self.parser:create_span(start_loc, end_loc)
                    return ast.create_call_expression(base, arguments, span.loc, span.range)
                end
            end

            -- 处理方法调用语法糖 (obj:method)
            if self.parser:check("COLON") then
                self.parser:advance()  -- 消耗 ':'
                if not self.parser:check("IDENTIFIER") then
                    self.parser:add_error("Expected identifier after ':'", self.parser:peek().loc)
                    return base
                end
                local method_token = self.parser:peek()
                self.parser:advance()
                local method = ast.create_identifier(method_token.value, method_token.loc, method_token.range)
                local span = self.parser:create_span(base.loc.start, method_token.loc["end"])
                base = ast.create_member_expression(base, method, false, span.loc, span.range)
                base.is_method_call = true  -- 标记为方法调用
            end

            -- 检查是否是函数调用
            if self.parser:check("LEFT_PAREN") then
                -- 这是一个函数调用，消耗'('并解析调用
                self.parser:advance()  -- 消耗 '('

                -- 解析参数列表
                local arguments = {}
                local start_loc = base.loc.start

                if not self.parser:check("RIGHT_PAREN") then
                    -- 解析参数
                    while true do
                        local arg = self:parse_expression()
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

                -- 处理方法调用语法糖
                if base.is_method_call then
                    -- 对于方法调用 obj:method()，自动添加obj作为第一个参数
                    table.insert(arguments, 1, base.base)
                    local method_call = ast.create_call_expression(
                        ast.create_member_expression(base.base, base.identifier, false, base.loc, base.range),
                        arguments, base.loc, {base.range[1], self.parser:previous().loc["end"] and self.parser:position_to_offset(self.parser:previous().loc["end"]) or base.range[2]}
                    )
                    return method_call
                else
                    -- 普通函数调用
                    local end_loc = self.parser:previous().loc["end"]
                    local span = self.parser:create_span(start_loc, end_loc)
                    return ast.create_call_expression(base, arguments, span.loc, span.range)
                end
            end

            return base
        end
    end

    -- 括号表达式
    if token.type == "LEFT_PAREN" then
        self.parser:advance()  -- 消耗 '('

        local expr = self:parse_expression()

        if not self.parser:expect("RIGHT_PAREN") then
            return expr  -- 返回部分解析结果
        end

        return expr
    end

    -- 函数表达式
    if token.type == "FUNCTION" then
        return self:parse_function_expression()
    end

    -- 表构造器
    if token.type == "LEFT_BRACE" then
        return self:parse_table_constructor()
    end

    -- 意外的 token
    self.parser:add_error(string.format("Unexpected token: %s", token.value), token.loc)
    self.parser:advance()  -- 跳过错误 token
    return nil
end

-- 解析函数调用表达式（标识符已经被消耗）
function ExpressionParser:parse_call_expression_from_identifier(identifier_token)
    local base = ast.create_identifier(identifier_token.value, identifier_token.loc, identifier_token.range)

    if not self.parser:expect("LEFT_PAREN") then
        return base
    end

    -- 解析参数列表
    local arguments = {}
    local start_loc = base.loc.start

    if not self.parser:check("RIGHT_PAREN") then
        -- 解析参数
        while true do
            local arg = self:parse_expression()
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
        return base
    end

    local end_loc = self.parser:previous().loc["end"]
    local span = {
        loc = {start = start_loc, ["end"] = end_loc},
        range = {base.range[1], end_loc and self.parser:position_to_offset(end_loc) or base.range[2]}
    }

    return ast.create_call_expression(base, arguments, span.loc, span.range)
end

-- 解析函数调用表达式（兼容旧接口）
function ExpressionParser:parse_call_expression()
    -- 注意：调用这个方法时，base表达式已经被消耗了
    -- 我们需要从previous()获取base表达式信息
    local base_expr = self.parser:previous()

    if not base_expr then
        self.parser:add_error("Expected expression for function call", self.parser:peek().loc)
        return nil
    end

    -- 处理方法调用语法糖
    if base_expr.is_method_call then
        -- 对于方法调用 obj:method()，我们需要：
        -- 1. 获取obj作为第一个参数
        -- 2. 构建参数列表：[obj, ...其他参数]
        local obj = base_expr.base  -- 方法调用中的对象
        local method_name = base_expr.identifier  -- 方法名

        if not self.parser:expect("LEFT_PAREN") then
            return nil
        end

        -- 解析参数列表
        local arguments = {obj}  -- 第一个参数是对象本身
        local start_loc = base_expr.loc.start

        if not self.parser:check("RIGHT_PAREN") then
            -- 解析其他参数
            while true do
                local arg = self:parse_expression()
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

        -- 构建方法调用：obj.method(obj, args...)
        local end_loc = self.parser:previous().loc["end"]
        local span = self.parser:create_span(start_loc, end_loc)

        -- 创建 obj.method 形式的成员表达式
        local member_expr = ast.create_member_expression(obj, method_name, false, span.loc, span.range)

        return ast.create_call_expression(member_expr, arguments, span.loc, span.range)
    else
        -- 处理普通函数调用
        if base_expr.type ~= "IDENTIFIER" and base_expr.type ~= "MemberExpression" then
            self.parser:add_error("Expected identifier or member expression for function call", self.parser:peek().loc)
            return nil
        end

        if not self.parser:expect("LEFT_PAREN") then
            return nil
        end

        -- 解析参数列表
        local arguments = {}
        local start_loc = base_expr.loc.start

        if not self.parser:check("RIGHT_PAREN") then
            -- 解析参数
            while true do
                local arg = self:parse_expression()
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
        local span = self.parser:create_span(start_loc, end_loc)

        return ast.create_call_expression(base_expr, arguments, span.loc, span.range)
    end
end

-- 解析函数表达式
function ExpressionParser:parse_function_expression()
    local start_token = self.parser:peek()
    self.parser:advance()  -- 消耗 'function'

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

    -- 解析函数体（重用语句解析器的函数体解析）
    local body = self.parser.statement_parser:parse_function_body()

    if not body then
        return nil
    end

    -- 创建函数表达式
    local span = self.parser:create_span(start_token.loc.start, self.parser:previous().loc["end"])
    return ast.create_function_expression(params, body, span.loc, span.range)
end

-- 解析表构造器
function ExpressionParser:parse_table_constructor()
    local start_token = self.parser:peek()
    self.parser:advance()  -- 消耗 '{'

    local fields = {}
    local start_loc = start_token.loc.start

    while not self.parser:check("RIGHT_BRACE") and not self.parser:is_at_end() do
        local field = self:parse_table_field()
        if field then
            table.insert(fields, field)
        end

        if not self.parser:check("COMMA") and not self.parser:check("SEMICOLON") then
            break
        end
        self.parser:advance()  -- 消耗分隔符
    end

    if not self.parser:expect("RIGHT_BRACE") then
        -- 即使没有右大括号也返回部分结果
        local end_loc = self.parser:previous() and self.parser:previous().loc["end"] or start_loc
        return ast.create_table_constructor(fields, {start=start_loc, ["end"]=end_loc}, {0,0})
    end

    local end_loc = self.parser:previous().loc["end"]
    local span = {
        loc = {start = start_loc, ["end"] = end_loc},
        range = {self.parser:position_to_offset(start_loc), self.parser:position_to_offset(end_loc)}
    }

    return ast.create_table_constructor(fields, span.loc, span.range)
end

-- 解析表字段
function ExpressionParser:parse_table_field()
    local token = self.parser:peek()

    -- [key] = value 形式
    if token.type == "LEFT_BRACKET" then
        self.parser:advance()  -- 消耗 '['

        local key = self:parse_expression()

        if not self.parser:expect("RIGHT_BRACKET") then
            return nil
        end

        if not self.parser:expect("EQUAL") then
            return nil
        end

        local value = self:parse_expression()

        if key and value and key.range and value.range then
            return ast.create_table_key(key, value, key.loc, {key.range[1], value.range[2]})
        end

        return nil
    end

    -- key = value 形式
    if token.type == "IDENTIFIER" and self.parser:peek(1) and self.parser:peek(1).type == "EQUAL" then
        local key_token = token
        self.parser:advance()  -- 消耗键
        self.parser:advance()  -- 消耗 =

        local value = self:parse_expression()

        if value then
            -- 计算结束位置
            local end_pos
            if value.range then
                end_pos = value.range[2] or value.range["end"] or key_token.range[2]
            elseif value.loc and value.loc["end"] then
                end_pos = self.parser:position_to_offset(value.loc["end"])
            else
                end_pos = key_token.range[2]
            end

            return ast.create_table_key_string(key_token.value, value, key_token.loc, {key_token.range[1], end_pos})
        end

        return nil
    end

    -- value 形式（数组元素）
    local value = self:parse_expression()
    if value then
        return ast.create_table_value(value, value.loc, value.range or {0, 0})
    end

    return nil
end

return M

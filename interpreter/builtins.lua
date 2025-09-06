--- Lua内置函数库
-- 提供Lua标准库的基本函数实现

local M = {}

--- 创建内置函数表
function M.create_builtins()
    local builtins = {}

    -- 基础库函数
    builtins.print = function(...)
        local args = {...}
        local output = {}
        for i, v in ipairs(args) do
            output[i] = tostring(v)
        end
        print(table.concat(output, "\t"))
    end

    builtins.type = function(v)
        local t = type(v)
        if t == "number" then
            return "number"
        elseif t == "string" then
            return "string"
        elseif t == "boolean" then
            return "boolean"
        elseif t == "table" then
            return "table"
        elseif t == "function" then
            return "function"
        elseif t == "nil" then
            return "nil"
        else
            return "unknown"
        end
    end

    builtins.tostring = function(v)
        if v == nil then
            return "nil"
        end
        return tostring(v)
    end

    builtins.tonumber = function(v, base)
        if base then
            return tonumber(v, base)
        end
        return tonumber(v)
    end

    -- 数学库函数
    builtins.math = {
        abs = math.abs,
        ceil = math.ceil,
        floor = math.floor,
        max = math.max,
        min = math.min,
        random = math.random,
        randomseed = math.randomseed,
        sqrt = math.sqrt,
        sin = math.sin,
        cos = math.cos,
        tan = math.tan,
        asin = math.asin,
        acos = math.acos,
        atan = math.atan,
        atan2 = math.atan2,
        exp = math.exp,
        log = math.log,
        log10 = math.log10,
        pow = math.pow,
        deg = math.deg,
        rad = math.rad,
        pi = math.pi
    }

    -- 字符串库函数
    builtins.string = {
        len = string.len,
        sub = string.sub,
        lower = string.lower,
        upper = string.upper,
        char = string.char,
        byte = string.byte,
        format = string.format,
        rep = string.rep,
        reverse = string.reverse,
        find = string.find,
        match = string.match,
        gmatch = string.gmatch,
        gsub = string.gsub
    }

    -- 表库函数
    builtins.table = {
        insert = table.insert,
        remove = table.remove,
        sort = table.sort,
        concat = table.concat,
        maxn = table.maxn
    }

    -- ipairs函数
    builtins.ipairs = function(t)
        return function(state, index)
            if not state then return nil end
            index = (index or 0) + 1
            if state[index] ~= nil then
                return index, state[index]
            end
        end, t, 0
    end

    -- pairs函数
    builtins.pairs = function(t)
        local key = nil
        return function()
            key = next(t, key)
            if key ~= nil then
                return key, t[key]
            end
        end
    end

    -- next函数
    builtins.next = next

    -- assert函数
    builtins.assert = function(v, message)
        if not v then
            error(message or "assertion failed!", 2)
        end
        return v
    end

    -- error函数
    builtins.error = function(message, level)
        level = level or 1
        error(message, level + 1)
    end

    -- pcall函数
    builtins.pcall = function(func, ...)
        local args = {...}
        local success, result1, result2, result3 = pcall(func, table.unpack(args))
        if success then
            return true, result1, result2, result3
        else
            -- 解析错误信息，移除调试信息前缀
            local error_msg = tostring(result1)
            -- 移除格式如 "file:line: message" 或 "(command line):line: message" 的前缀
            local pattern = "^.*:%s*(.*)$"
            local cleaned_msg = error_msg:match(pattern) or error_msg
            return false, cleaned_msg
        end
    end

    -- select函数
    builtins.select = function(index, ...)
        if index == "#" then
            return select("#", ...)
        elseif index == 0 then
            return select(0, ...)
        else
            return select(index, ...)
        end
    end

    -- OS库函数
    builtins.os = {
        clock = os.clock,
        difftime = os.difftime,
        time = os.time,
        date = os.date,
        getenv = os.getenv
    }

    -- Debug库函数（简化版本）
    builtins.debug = {
        traceback = function(message, level)
            return "Debug traceback: " .. (message or "no message") .. " at level " .. (level or 1)
        end,
        getinfo = function(func, what)
            return {name = "function", source = "interpreter", linedefined = 0, lastlinedefined = 0}
        end
    }

    -- 位运算函数（Lua 5.3）
    builtins.bit32 = {
        band = function(a, b) return a & b end,
        bor = function(a, b) return a | b end,
        bxor = function(a, b) return a ~ b end,
        bnot = function(a) return ~a end,
        lshift = function(a, n) return a << n end,
        rshift = function(a, n) return a >> n end,
        arshift = function(a, n) return a >> n end,  -- 算术右移
    }

    -- UTF-8库函数（Lua 5.3）
    builtins.utf8 = {
        len = function(s, i, j)
            return string.len(s)  -- 简化实现
        end,
        char = function(...)
            local args = {...}
            local result = ""
            for _, code in ipairs(args) do
                result = result .. string.char(code)
            end
            return result
        end,
        codes = function(s)
            local i = 0
            return function()
                i = i + 1
                if i <= #s then
                    return i, string.byte(s, i)
                end
            end
        end
    }

    -- 协程库函数
    builtins.coroutine = {
        create = function(f)
            return {func = f, status = "suspended"}
        end,
        resume = function(co, ...)
            if co.status == "suspended" then
                co.status = "running"
                return true, co.func(...)
            else
                return false, "cannot resume non-suspended coroutine"
            end
        end,
        status = function(co)
            return co.status or "dead"
        end,
        yield = function(...)
            error("coroutine.yield not implemented in interpreter")
        end
    }

    -- Lua 5.3+ 增强功能
    builtins.math.tointeger = function(x)
        if type(x) == "number" and x == math.floor(x) then
            return x
        end
        return nil
    end

    builtins.math.type = function(x)
        if type(x) ~= "number" then
            return nil
        elseif x == math.floor(x) then
            return "integer"
        else
            return "float"
        end
    end

    builtins.math.ult = function(a, b)
        return a < b
    end

    -- 增强的字符串函数
    builtins.string.pack = function(fmt, ...)
        -- 简化的pack实现
        return "packed_data"
    end

    builtins.string.unpack = function(fmt, s, pos)
        -- 简化的unpack实现
        return "unpacked_data"
    end

    builtins.string.packsize = function(fmt)
        return 0  -- 简化实现
    end

    -- 表增强函数
    builtins.table.move = function(a1, f, e, t, a2)
        a2 = a2 or a1
        if t < f then
            for i = f, e do
                a2[t + i - f] = a1[i]
            end
        else
            for i = e, f, -1 do
                a2[t + i - f] = a1[i]
            end
        end
        return a2
    end

    -- 实用工具函数
    builtins.tonumber = function(e, base)
        return tonumber(e, base)
    end

    builtins.tostring = function(v)
        return tostring(v)
    end

    builtins.type = function(v)
        return type(v)
    end

    builtins.pairs = function(t)
        return next, t, nil
    end

    builtins.ipairs = function(t)
        return function(state, i)
            i = (i or 0) + 1
            if state[i] ~= nil then
                return i, state[i]
            end
        end, t, 0
    end

    -- 错误处理函数
    builtins.assert = function(v, message)
        if not v then
            error(message or "assertion failed!")
        end
        return v, message
    end

    builtins.error = function(message, level)
        error(message, level)
    end

    -- 元表操作函数
    builtins.setmetatable = function(table, metatable)
        -- 在我们的解释器中，我们需要手动实现元表功能
        -- 设置完整的元表
        table.__metatable = metatable

        -- 如果设置了__index，我们需要创建一个包装函数来处理查找
        if metatable and metatable.__index then
            -- 保存原始的__index
            table.__original_index = metatable.__index

            -- 创建一个包装函数来处理成员访问
            table.__index_wrapper = function(tbl, key)
                -- 直接查找__index，避免递归
                local index_value = metatable.__index
                if type(index_value) == "table" then
                    return rawget(index_value, key)
                elseif type(index_value) == "function" then
                    return index_value(tbl, key)
                end

                return nil
            end
        end

        return table
    end

    builtins.getmetatable = function(table)
        return table.__metatable or nil
    end

    -- rawget函数
    builtins.rawget = function(table, key)
        return rawget(table, key)
    end

    -- rawset函数
    builtins.rawset = function(table, key, value)
        rawset(table, key, value)
        return table
    end

    return builtins
end

return M

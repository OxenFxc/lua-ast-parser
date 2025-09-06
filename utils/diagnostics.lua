-- 诊断与错误恢复工具

local M = {}

-- 诊断级别
M.SEVERITY = {
    ERROR = "error",
    WARNING = "warning",
    INFO = "info",
    HINT = "hint"
}

-- 创建诊断对象
-- @param severity string 严重级别
-- @param message string 错误消息
-- @param loc table 位置信息
-- @param source string 源标识（如 "lexer", "parser"）
function M.create_diagnostic(severity, message, loc, source)
    return {
        severity = severity,
        message = message,
        loc = loc,
        source = source or "unknown",
        timestamp = os.time()
    }
end

-- 诊断收集器类
local DiagnosticCollector = {}
DiagnosticCollector.__index = DiagnosticCollector

-- 创建新的诊断收集器
function M.create_collector()
    local self = setmetatable({}, DiagnosticCollector)
    self.diagnostics = {}
    self.error_count = 0
    self.warning_count = 0
    return self
end

-- 添加诊断
function DiagnosticCollector:add(diagnostic)
    table.insert(self.diagnostics, diagnostic)
    
    if diagnostic.severity == M.SEVERITY.ERROR then
        self.error_count = self.error_count + 1
    elseif diagnostic.severity == M.SEVERITY.WARNING then
        self.warning_count = self.warning_count + 1
    end
end

-- 添加错误
function DiagnosticCollector:add_error(message, loc, source)
    self:add(M.create_diagnostic(M.SEVERITY.ERROR, message, loc, source))
end

-- 添加警告
function DiagnosticCollector:add_warning(message, loc, source)
    self:add(M.create_diagnostic(M.SEVERITY.WARNING, message, loc, source))
end

-- 添加信息
function DiagnosticCollector:add_info(message, loc, source)
    self:add(M.create_diagnostic(M.SEVERITY.INFO, message, loc, source))
end

-- 是否有错误
function DiagnosticCollector:has_errors()
    return self.error_count > 0
end

-- 获取所有诊断
function DiagnosticCollector:get_diagnostics()
    return self.diagnostics
end

-- 清空诊断
function DiagnosticCollector:clear()
    self.diagnostics = {}
    self.error_count = 0
    self.warning_count = 0
end

-- 格式化诊断为字符串
function M.format_diagnostic(diagnostic, source_text)
    local parts = {}
    
    -- 添加位置信息
    if diagnostic.loc then
        local start = diagnostic.loc.start
        table.insert(parts, string.format("%d:%d", start.line, start.column))
    end
    
    -- 添加严重级别
    table.insert(parts, string.format("[%s]", diagnostic.severity:upper()))
    
    -- 添加源
    if diagnostic.source then
        table.insert(parts, string.format("(%s)", diagnostic.source))
    end
    
    -- 添加消息
    table.insert(parts, diagnostic.message)
    
    local result = table.concat(parts, " ")
    
    -- 如果有源文本和位置，添加代码片段
    if source_text and diagnostic.loc then
        local lines = {}
        for line in source_text:gmatch("[^\n]*") do
            table.insert(lines, line)
        end
        
        local line_num = diagnostic.loc.start.line
        if line_num <= #lines then
            result = result .. "\n" .. lines[line_num] .. "\n"
            
            -- 添加错误指示器
            local indicator = string.rep(" ", diagnostic.loc.start.column - 1) .. "^"
            result = result .. indicator
        end
    end
    
    return result
end

-- 格式化所有诊断
function M.format_all_diagnostics(diagnostics, source_text)
    local results = {}
    for _, diagnostic in ipairs(diagnostics) do
        table.insert(results, M.format_diagnostic(diagnostic, source_text))
    end
    return table.concat(results, "\n\n")
end

-- 错误恢复策略
M.RECOVERY = {
    -- 同步到下一个语句
    SYNC_STATEMENT = "sync_statement",
    -- 同步到下一个表达式
    SYNC_EXPRESSION = "sync_expression",
    -- 跳过当前 token
    SKIP_TOKEN = "skip_token",
    -- 插入缺失的 token
    INSERT_TOKEN = "insert_token"
}

-- 错误恢复器类
local ErrorRecovery = {}
ErrorRecovery.__index = ErrorRecovery

-- 创建错误恢复器
function M.create_recovery()
    local self = setmetatable({}, ErrorRecovery)
    self.sync_tokens = {
        -- 语句同步点
        ["end"] = true,
        ["else"] = true,
        ["elseif"] = true,
        ["until"] = true,
        [";"] = true,
        
        -- 表达式同步点
        [","] = true,
        [")"] = true,
        ["}"] = true,
        ["]"] = true
    }
    return self
end

-- 判断是否为同步 token
function ErrorRecovery:is_sync_token(token_type)
    return self.sync_tokens[token_type] ~= nil
end

-- 添加自定义同步 token
function ErrorRecovery:add_sync_token(token_type)
    self.sync_tokens[token_type] = true
end

-- 移除同步 token
function ErrorRecovery:remove_sync_token(token_type)
    self.sync_tokens[token_type] = nil
end

return M

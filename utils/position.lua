-- 位置与范围计算工具

local M = {}

-- 创建位置对象
-- @param line number 行号（1-based）
-- @param column number 列号（1-based）
function M.create_position(line, column)
    return {
        line = line or 1,
        column = column or 1
    }
end

-- 创建位置范围
-- @param start_pos table 起始位置
-- @param end_pos table 结束位置
function M.create_location(start_pos, end_pos)
    return {
        start = start_pos,
        ["end"] = end_pos  -- end 是 Lua 关键字，需要用引号
    }
end

-- 创建字符偏移范围
-- @param start_offset number 起始偏移（0-based）
-- @param end_offset number 结束偏移（0-based）
function M.create_range(start_offset, end_offset)
    return { start_offset, end_offset }
end

-- 位置跟踪器类
local PositionTracker = {}
PositionTracker.__index = PositionTracker

-- 创建新的位置跟踪器
function M.create_tracker(source)
    local self = setmetatable({}, PositionTracker)
    self.source = source
    self.line = 1
    self.column = 1
    self.offset = 0
    self.line_starts = {1}  -- 每行的起始偏移
    return self
end

-- 前进 n 个字符
function PositionTracker:advance(n)
    n = n or 1
    for i = 1, n do
        if self.offset < #self.source then
            self.offset = self.offset + 1
            local char = self.source:sub(self.offset, self.offset)
            
            if char == "\n" then
                self.line = self.line + 1
                self.column = 1
                table.insert(self.line_starts, self.offset + 1)
            elseif char == "\r" then
                -- 处理 \r\n
                if self.offset < #self.source and 
                   self.source:sub(self.offset + 1, self.offset + 1) == "\n" then
                    self.offset = self.offset + 1
                end
                self.line = self.line + 1
                self.column = 1
                table.insert(self.line_starts, self.offset + 1)
            else
                self.column = self.column + 1
            end
        end
    end
end

-- 获取当前位置
function PositionTracker:get_position()
    return M.create_position(self.line, self.column)
end

-- 获取当前偏移
function PositionTracker:get_offset()
    return self.offset
end

-- 标记起始位置
function PositionTracker:mark_start()
    return {
        position = self:get_position(),
        offset = self.offset
    }
end

-- 创建从标记到当前位置的范围
function PositionTracker:create_span(mark)
    return {
        loc = M.create_location(mark.position, self:get_position()),
        range = M.create_range(mark.offset, self.offset)
    }
end

-- 从偏移计算位置
function M.offset_to_position(source, offset)
    local line = 1
    local column = 1
    
    for i = 1, math.min(offset, #source) do
        local char = source:sub(i, i)
        if char == "\n" then
            line = line + 1
            column = 1
        elseif char == "\r" then
            if i < #source and source:sub(i + 1, i + 1) == "\n" then
                -- 跳过 \r\n 中的 \n
            end
            line = line + 1
            column = 1
        else
            column = column + 1
        end
    end
    
    return M.create_position(line, column)
end

-- 从位置计算偏移
function M.position_to_offset(source, position)
    local line = 1
    local column = 1
    local offset = 0
    
    for i = 1, #source do
        if line == position.line and column == position.column then
            return offset
        end
        
        local char = source:sub(i, i)
        offset = offset + 1
        
        if char == "\n" then
            line = line + 1
            column = 1
        elseif char == "\r" then
            if i < #source and source:sub(i + 1, i + 1) == "\n" then
                offset = offset + 1
            end
            line = line + 1
            column = 1
        else
            column = column + 1
        end
    end
    
    return offset
end

return M

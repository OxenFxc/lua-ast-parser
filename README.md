# LuaAstParser

[English](#english) | [中文](#中文)

---

## 中文

一个用纯 Lua 实现的完整 Lua 解析器，支持从 Lua 源码到 AST 的转换、AST 到 Lua 源码的打印，以及 AST 的解释执行。

### 功能特性

- **完整的词法分析器**：支持所有 Lua 标记类型，包括关键字、标识符、字面量等
- **递归下降语法分析器**：实现完整的 Lua 语法解析，支持表达式和语句
- **AST 构建**：构建结构化的抽象语法树，支持访问者模式
- **代码打印器**：将 AST 转换为格式化的 Lua 源码
- **AST 解释器**：纯 Lua 实现的 AST 执行引擎，支持大部分 Lua 特性
- **插件系统**：可扩展的插件架构，支持自定义语法和功能
- **诊断系统**：完整的错误诊断和位置追踪
- **工具库**：丰富的字符串、表格、位置处理工具

### 项目结构

```
lua/
├── ast/              # 抽象语法树模块
│   ├── init.lua      # AST 主入口和工厂
│   ├── nodes.lua     # AST 节点定义
│   └── visitor.lua   # 访问者模式实现
├── interpreter/      # AST 解释器
│   ├── init.lua      # 解释器主入口
│   └── builtins.lua  # 内置函数实现
├── lexer/            # 词法分析器
│   ├── init.lua      # 词法器主入口
│   ├── scanner.lua   # 扫描器实现
│   ├── token.lua     # Token 定义
│   └── keywords.lua  # 关键字定义
├── parser/           # 语法分析器
│   ├── init.lua      # 语法器主入口
│   ├── expressions.lua # 表达式解析
│   ├── statements.lua  # 语句解析
│   └── precedence.lua   # 运算符优先级
├── printer/          # 代码打印器
│   ├── init.lua      # 打印器主入口
│   ├── emitter.lua   # 代码发射器
│   └── formatter.lua # 格式化器
├── plugins/          # 插件系统
│   └── example_plugins.lua # 示例插件
├── utils/            # 工具库
│   ├── diagnostics.lua # 诊断系统
│   ├── position.lua    # 位置处理
│   ├── string_ext.lua  # 字符串扩展
│   └── table_ext.lua   # 表格扩展
├── init.lua          # 主入口
└── plugins.lua       # 插件管理器
```

### 快速开始

#### 基本使用

```lua
local luaparser = require("lua")

-- 解析 Lua 源码为 AST
local success, result = luaparser.parse_lua("print('Hello, World!')")
if success then
    local ast = result
    print("解析成功")
end

-- 将 AST 转换为 Lua 源码
local success, result = luaparser.print_lua(ast)
if success then
    local code = result.code
    print(code)  -- 输出: print('Hello, World!')
end

-- 解释执行 AST
local success, result = luaparser.interpret_lua(ast)
if success then
    print("执行结果:", result)
end
```

#### 插件系统

```lua
-- 注册自定义插件
local my_plugin = {
    name = "my_plugin",
    version = "1.0.0",
    description = "My custom plugin",

    init = function(config)
        print("Plugin initialized")
    end,

    extend_lexer = function(lexer)
        -- 扩展词法器
    end,

    extend_parser = function(parser)
        -- 扩展语法器
    end
}

luaparser.register_plugin(my_plugin)
luaparser.load_plugin("my_plugin")
```

### API 文档

#### 核心函数

- `parse_lua(source, options)` - 解析 Lua 源码为 AST
- `print_lua(ast, options)` - 将 AST 转换为 Lua 源码
- `interpret_lua(ast, options)` - 解释执行 AST

#### 插件 API

- `register_plugin(plugin)` - 注册插件
- `load_plugin(name, config)` - 加载插件
- `unload_plugin(name)` - 卸载插件
- `get_plugin(name)` - 获取插件实例

### 许可证

本项目采用 MIT 许可证 - 详见 [LICENSE](LICENSE) 文件

---

## English

A complete Lua parser implemented in pure Lua, supporting conversion from Lua source code to AST, AST to Lua source code printing, and AST interpretation execution.

### Features

- **Complete Lexer**: Supports all Lua token types, including keywords, identifiers, literals, etc.
- **Recursive Descent Parser**: Implements complete Lua syntax parsing, supporting expressions and statements
- **AST Construction**: Builds structured abstract syntax trees, supports visitor pattern
- **Code Printer**: Converts AST to formatted Lua source code
- **AST Interpreter**: Pure Lua implementation of AST execution engine, supports most Lua features
- **Plugin System**: Extensible plugin architecture, supports custom syntax and functionality
- **Diagnostics System**: Complete error diagnostics and position tracking
- **Utility Library**: Rich string, table, and position handling utilities

### Project Structure

```
lua/
├── ast/              # Abstract Syntax Tree module
│   ├── init.lua      # AST main entry and factory
│   ├── nodes.lua     # AST node definitions
│   └── visitor.lua   # Visitor pattern implementation
├── interpreter/      # AST Interpreter
│   ├── init.lua      # Interpreter main entry
│   └── builtins.lua  # Built-in functions implementation
├── lexer/            # Lexical Analyzer
│   ├── init.lua      # Lexer main entry
│   ├── scanner.lua   # Scanner implementation
│   ├── token.lua     # Token definitions
│   └── keywords.lua  # Keywords definitions
├── parser/           # Syntax Parser
│   ├── init.lua      # Parser main entry
│   ├── expressions.lua # Expression parsing
│   ├── statements.lua  # Statement parsing
│   └── precedence.lua   # Operator precedence
├── printer/          # Code Printer
│   ├── init.lua      # Printer main entry
│   ├── emitter.lua   # Code emitter
│   └── formatter.lua # Formatter
├── plugins/          # Plugin System
│   └── example_plugins.lua # Example plugins
├── utils/            # Utility Library
│   ├── diagnostics.lua # Diagnostics system
│   ├── position.lua    # Position handling
│   ├── string_ext.lua  # String extensions
│   └── table_ext.lua   # Table extensions
├── init.lua          # Main entry
└── plugins.lua       # Plugin manager
```

### Quick Start

#### Basic Usage

```lua
local luaparser = require("lua")

-- Parse Lua source code to AST
local success, result = luaparser.parse_lua("print('Hello, World!')")
if success then
    local ast = result
    print("Parse successful")
end

-- Convert AST to Lua source code
local success, result = luaparser.print_lua(ast)
if success then
    local code = result.code
    print(code)  -- Output: print('Hello, World!')
end

-- Interpret and execute AST
local success, result = luaparser.interpret_lua(ast)
if success then
    print("Execution result:", result)
end
```

#### Plugin System

```lua
-- Register custom plugin
local my_plugin = {
    name = "my_plugin",
    version = "1.0.0",
    description = "My custom plugin",

    init = function(config)
        print("Plugin initialized")
    end,

    extend_lexer = function(lexer)
        -- Extend lexer
    end,

    extend_parser = function(parser)
        -- Extend parser
    end
}

luaparser.register_plugin(my_plugin)
luaparser.load_plugin("my_plugin")
```

### API Documentation

#### Core Functions

- `parse_lua(source, options)` - Parse Lua source code to AST
- `print_lua(ast, options)` - Convert AST to Lua source code
- `interpret_lua(ast, options)` - Interpret and execute AST

#### Plugin API

- `register_plugin(plugin)` - Register plugin
- `load_plugin(name, config)` - Load plugin
- `unload_plugin(name)` - Unload plugin
- `get_plugin(name)` - Get plugin instance

### License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details

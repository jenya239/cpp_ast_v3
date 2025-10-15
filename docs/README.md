# CppAst Documentation

## Project Overview

CppAst is a lossless C++ parser and AST builder with DSL for code generation. It preserves exact whitespace and formatting for perfect roundtrip capability.

## Core Documentation

### Architecture
- **[cpp_parser_arch.md](cpp_parser_arch.md)** - Core lossless CST parser architecture
- **[WHITESPACE_POLICY.md](WHITESPACE_POLICY.md)** - Whitespace management rules
- **[../ARCHITECTURE_WHITESPACE_GUIDE.md](../ARCHITECTURE_WHITESPACE_GUIDE.md)** - Complete guide to whitespace architecture (with troubleshooting)

### Aurora DSL
- **[AURORA_DSL.md](AURORA_DSL.md)** - Aurora language DSL specification

## Project Status

**Test Results:** 890/958 passing (68 failures)
- Whitespace architecture: ✅ Fixed (113 → 68 failures)
- Remaining issues: Match expressions, nested namespaces, error handling

## Quick Start

### Running Tests
```bash
bundle exec rake test
```

### Parsing C++ Code
```ruby
require 'cpp_ast'

ast = CppAst.parse('void foo() const;')
puts ast.to_source  # => "void foo() const;"
```

### Generating C++ Code via DSL
```ruby
require 'cpp_ast'
include CppAst::Builder::DSL

ast = function_decl('void', 'foo', []).const
puts ast.to_source  # => "void foo() const;"
```

### Roundtrip via DSL
```ruby
require 'cpp_ast'
include CppAst::Builder::DSL

# Parse → DSL code → new AST
ast1 = CppAst.parse('void foo() const;')
dsl_code = CppAst.to_dsl(ast1)
ast2 = eval(dsl_code)

ast1.to_source == ast2.to_source  # => true
```

## Development

### Finding Whitespace Issues
See [../ARCHITECTURE_WHITESPACE_GUIDE.md](../ARCHITECTURE_WHITESPACE_GUIDE.md) for:
- How to detect whitespace violations
- Testing parser vs DSL consistency
- Step-by-step debugging guide

### Adding New Node Types
Follow the checklist in [../ARCHITECTURE_WHITESPACE_GUIDE.md](../ARCHITECTURE_WHITESPACE_GUIDE.md#checklist-for-new-node-types)

## Contributing

When modifying AST nodes:
1. Never add explicit spaces in `to_source` methods
2. Store all whitespace in suffix/trivia fields
3. Ensure parser and DSL produce identical output
4. Add roundtrip tests

# C++ AST Parser (V3) - Clean Architecture

Pure Ruby C++ parser with **100% roundtrip accuracy**.

## Architectural Principles

✅ **Perfect whitespace preservation**: `source -> AST -> to_source == source`  
✅ **Clean architecture**: Separate lexer, parser, nodes layers  
✅ **TDD from day 1**: Comprehensive test coverage  
✅ **Ruby way**: Idiomatic, simple, maintainable  
✅ **No circular dependencies**: Clear module boundaries  
✅ **Explicit trivia flow**: Parent owns spacing between children

## Key Design Decisions

### 1. Nodes Don't Own Trailing Trivia
```ruby
# ✅ GOOD: Node only contains its syntax
class Identifier < Expression
  attr_accessor :name
  
  def to_source
    name  # No trailing trivia!
  end
end
```

### 2. Parsers Return Tuples
```ruby
# All parse_* methods return (node, trailing_trivia)
def parse_expression
  expr = create_expression
  trailing = collect_trivia_string
  [expr, trailing]
end
```

### 3. Parent Ownership
```ruby
# Parent manages spacing between children
class Program
  attr_accessor :statements, :statement_trailings
  
  def to_source
    statements.zip(statement_trailings).map { |stmt, trailing|
      stmt.to_source + trailing
    }.join
  end
end
```

## Architecture

```
cpp_ast/
├── lexer/      # Tokenization (no dependencies)
├── nodes/      # AST nodes (pure data, no logic)
├── parsers/    # Parsing logic (depends only on lexer + nodes)
└── rewriters/  # AST manipulation (depends on nodes)
```

## Installation

```bash
bundle install
```

## Usage

```ruby
require "cpp_ast"

source = "x = 42;\n"
program = CppAst.parse(source)

puts program.to_source  # => "x = 42;\n"
```

## Running Tests

```bash
# All tests
rake test

# Specific test file
ruby test/lexer/test_token.rb
```

## Development Status

**TOTAL: 481 tests, 630 assertions, 0 failures, 0 errors** ✅

### ✅ Supported Constructs
- ✅ All operators (binary, unary, ternary, member access, subscript)
- ✅ Control flow (if/else, loops, switch, break, continue)
- ✅ Declarations (variables, functions, classes, structs, enums)
- ✅ Templates (class/function templates, specialization)
- ✅ Constructors, destructors, operators
- ✅ Inheritance, namespaces, using declarations
- ✅ Attributes, preprocessor directives
- ✅ Lambdas, initializer lists
- ✅ 100% roundtrip accuracy

### Current Architecture Status
✅ **Roundtrip**: 100% (481/481 tests)  
✅ **Architecture**: Clean, functional  
⚠️ **CST compliance**: 9/10 (trivia not in tokens yet)

### Next Steps
See `docs/TRIVIA_REFACTORING_PLAN.md` for Phase 2 improvements

## Contributing

This project follows strict TDD:
1. Write test first (RED)
2. Make it pass (GREEN)
3. Refactor (REFACTOR)
4. Commit

## License

MIT

## Documentation

- [docs/CST_ARCHITECTURE_SUMMARY.md](docs/CST_ARCHITECTURE_SUMMARY.md) - Executive summary
- [docs/TRIVIA_REFACTORING_PLAN.md](docs/TRIVIA_REFACTORING_PLAN.md) - Next phase plan
- [docs/README.md](docs/README.md) - Full documentation index


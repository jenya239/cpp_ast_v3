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

### ✅ Phase 1: MVP (COMPLETED)
- ✅ Lexer (identifiers, numbers, operators, whitespace, comments) - **7 tests**
- ✅ Nodes (expressions, statements, program) - **25 tests**
- ✅ Parsers (expression, statement, program) - **48 tests**
- ✅ 100% roundtrip for simple programs - **20 integration tests**

**TOTAL: 104 tests, 171 assertions, 0 failures, 0 errors**

### Supported Constructs
- ✅ Identifiers, Number literals
- ✅ Binary expressions (+, -, *, /, =) with correct precedence
- ✅ Assignment (right-associative)
- ✅ Expression statements
- ✅ Return statements
- ✅ Multiple statements in program
- ✅ Perfect whitespace/comment preservation
- ✅ Line comments (`// ...`)

### Phase 2: Extensions (Ready to implement)
- [ ] More operators (comparison, logical, bitwise)
- [ ] Unary operators (!, ++, --, -, +)
- [ ] Parenthesized expressions
- [ ] More statements (if/else, loops, switch)
- [ ] Declarations (variables, functions, classes)
- [ ] Rewriter support

## Contributing

This project follows strict TDD:
1. Write test first (RED)
2. Make it pass (GREEN)
3. Refactor (REFACTOR)
4. Commit

## License

MIT

## Related Documentation

See [AI_AGENT_IMPLEMENTATION_GUIDE.md](../cpp_ast_ruby/docs/AI_AGENT_IMPLEMENTATION_GUIDE.md) for complete implementation guide.


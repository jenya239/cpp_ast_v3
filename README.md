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

### Parsing C++ Code
```ruby
require "cpp_ast"

source = "x = 42;\n"
program = CppAst.parse(source)

puts program.to_source  # => "x = 42;\n"
```

### DSL Builder - Bidirectional

**DSL → AST → C++**
```ruby
require "cpp_ast"
include CppAst::Builder::DSL

ast = program(
  function_decl("int", "main", [],
    block(return_stmt(int(0)))
  )
)

puts ast.to_source
# => int main( ){
#    return 0;
#    }
```

**C++ → AST → DSL (NEW!)**
```ruby
cpp_code = "int main(){\nreturn 0;\n}\n"
ast = CppAst.parse(cpp_code)
dsl_code = CppAst.to_dsl(ast)

puts dsl_code
# => program(
#      function_decl("int", "main", [],
#        block(return_stmt(int(0)))
#      )
#    )

# Perfect roundtrip: eval DSL → AST → C++ (identical!)
```

**Fluent API для trivia**
```ruby
ast = function_decl("int", "main", [], block(...))
  .with_rparen_suffix("")
  .with_leading("\n")
```

### Aurora DSL Extensions (NEW!)

**Modern C++ через Ruby DSL**:
```ruby
# Ownership types
owned("Vec2")        # std::unique_ptr<Vec2>
borrowed("Vec2")     # const Vec2&
span_of("int")       # std::span<int>

# ADT (Algebraic Data Types)
product_type("Point",
  field_def("x", "float"),
  field_def("y", "float")
)

sum_type("Shape",
  case_struct("Circle", field_def("r", "float")),
  case_struct("Rect", field_def("w", "float"), field_def("h", "float"))
)

# Pattern Matching
match_expr(id("shape"),
  arm("Circle", ["r"], binary("*", float(3.14), binary("*", id("r"), id("r")))),
  arm("Rect", ["w", "h"], binary("*", id("w"), id("h")))
)

# Result/Option types
result_of("int", "std::string")  # std::expected<int, std::string>
option_of("float")               # std::optional<float>
```

См. `docs/AURORA_DSL.md` для полной документации и `examples/04_aurora_dsl.rb` для примеров.

## Running Tests

```bash
# All tests
rake test

# Specific test file
ruby test/lexer/test_token.rb
```

## Development Status

**TOTAL: 703 tests, 913 assertions, 0 failures, 0 errors** ✅

### ✅ Supported Constructs
- ✅ All operators (binary, unary, ternary, member access, subscript)
- ✅ Control flow (if/else, loops, switch, break, continue)
- ✅ Declarations (variables, functions, classes, structs, enums)
- ✅ Templates (class/function templates, specialization)
- ✅ Constructors, destructors, operators
- ✅ Inheritance, namespaces, using declarations
- ✅ Attributes, preprocessor directives
- ✅ Lambdas, initializer lists
- ✅ **DSL Builder** для программного создания AST
- ✅ **DSL Generator** - C++ → DSL код (bidirectional)
- ✅ **Fluent API** для точного контроля trivia
- ✅ 100% roundtrip accuracy (C++ ↔ DSL)

### Current Architecture Status
✅ **Roundtrip**: 100% (653/653 tests, включая bidirectional DSL)  
✅ **Architecture**: Clean, functional  
✅ **Bidirectional**: C++ ↔ AST ↔ DSL (perfect roundtrip)  
✅ **Edge Cases**: Unicode, line endings, empty files  
✅ **Trivia in Tokens**: Lossless CST architecture  
✅ **CST compliance**: 10/10 (полная реализация эталона)

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


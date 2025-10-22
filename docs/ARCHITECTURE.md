# Architecture Overview

## System Components

### 1. Aurora Language Compiler

```
Aurora Source → Lexer → Parser → AST → CoreIR → C++ AST → C++ Code
```

#### Lexer (`lib/aurora/parser/lexer.rb`)
- Tokenizes Aurora source code
- Handles comments, whitespace, and trivia
- Supports Unicode and modern syntax

#### Parser (`lib/aurora/parser/parser.rb`)
- Recursive descent parser
- Handles all Aurora language constructs
- Generates AST nodes

#### CoreIR (`lib/aurora/core_ir/`)
- Intermediate representation
- Type system and inference
- Optimizations and transformations

#### C++ Lowering (`lib/aurora/backend/`)
- Converts CoreIR to C++ AST
- Handles type mapping
- Generates modern C++ code

### 2. C++ AST DSL

```
Ruby DSL → C++ AST → C++ Code
```

#### DSL Builder (`lib/cpp_ast/builder/`)
- Fluent API for C++ code generation
- Supports all C++ features
- Template and modern C++ support

#### AST Nodes (`lib/cpp_ast/nodes/`)
- Represent C++ language constructs
- Handle formatting and code generation
- Support roundtrip parsing

#### Code Generation (`lib/cpp_ast/builder/dsl_generator.rb`)
- Converts AST to C++ source
- Handles formatting and style
- Supports multiple output modes

## Data Flow

### Aurora Compilation Pipeline

1. **Source Input**
   ```aurora
   fn main() -> i32 = 42
   ```

2. **Lexical Analysis**
   ```
   [fn] [main] [(] [)] [->] [i32] [=] [42]
   ```

3. **Parsing**
   ```
   FuncDecl(name: "main", params: [], ret_type: "i32", body: IntLit(42))
   ```

4. **CoreIR Transformation**
   ```
   CoreIR::Func(name: "main", params: [], ret_type: i32, body: CoreIR::Literal(42))
   ```

5. **C++ Lowering**
   ```
   CppAst::FunctionDeclaration(return_type: "int", name: "main", body: "return 42;")
   ```

6. **Code Generation**
   ```cpp
   int main() { return 42; }
   ```

### C++ AST DSL Pipeline

1. **DSL Construction**
   ```ruby
   function_decl("int", "main", [], block(return_stmt(int(42))))
   ```

2. **AST Building**
   ```
   FunctionDeclaration.new(return_type: "int", name: "main", body: Block([ReturnStatement(IntLiteral(42))]))
   ```

3. **Code Generation**
   ```cpp
   int main() { return 42; }
   ```

## Key Design Decisions

### 1. Modular Architecture
- **Separation of Concerns**: Each component has a single responsibility
- **Loose Coupling**: Components communicate through well-defined interfaces
- **Extensibility**: Easy to add new features and optimizations

### 2. AST-Based Design
- **Roundtrip Support**: Parse → AST → Generate preserves information
- **Extensibility**: Easy to add new language constructs
- **Optimization**: AST transformations enable optimizations

### 3. Type System
- **Structural Typing**: Types are inferred from usage
- **Generic Support**: Parametric polymorphism with constraints
- **Type Safety**: Compile-time error checking

### 4. Performance Optimizations
- **Memoization**: Parser results are cached
- **StringBuilder**: Efficient string concatenation
- **Object Pooling**: Reuse of AST nodes
- **Lazy Evaluation**: Deferred computation where possible

## Component Details

### Parser Architecture

```ruby
class Parser
  def initialize(source, filename: nil)
    @lexer = Lexer.new(source, filename: filename)
    @tokens = @lexer.tokenize
    @pos = 0
  end
  
  def parse
    parse_program
  end
  
  private
  
  def parse_program
    # Parse module, imports, declarations
  end
  
  def parse_function
    # Parse function declarations
  end
  
  def parse_expression
    # Parse expressions with precedence
  end
end
```

### AST Node Hierarchy

```
BaseNode
├── Program
├── Declaration
│   ├── FuncDecl
│   └── TypeDecl
├── Expression
│   ├── Literal
│   ├── BinaryOp
│   ├── Call
│   └── Match
└── Statement
    ├── ReturnStmt
    ├── VarDecl
    └── Block
```

### Type System

```ruby
module TypeSystem
  class Type
    def compatible?(other)
      # Type compatibility checking
    end
    
    def unify(other)
      # Type unification
    end
  end
  
  class PrimitiveType < Type
    # i32, f32, bool, str
  end
  
  class FunctionType < Type
    # Function signature types
  end
  
  class GenericType < Type
    # Template/parametric types
  end
end
```

## Error Handling Architecture

### Error Hierarchy

```
StandardError
├── Aurora::ParseError
├── Aurora::CompileError
├── Aurora::EnhancedError
│   ├── Aurora::SyntaxError
│   ├── Aurora::TypeError
│   ├── Aurora::ScopeError
│   └── Aurora::ImportError
└── Aurora::Parser::MultipleErrors
```

### Error Recovery

1. **Parse Error Recovery**: Skip to next declaration
2. **Type Error Recovery**: Continue with default types
3. **Multiple Error Reporting**: Collect all errors before failing
4. **Rich Diagnostics**: Provide suggestions and context

## Performance Architecture

### Optimization Strategies

1. **Parser Optimizations**
   - Memoization of parse results
   - Lookahead optimization
   - Token caching

2. **Code Generation Optimizations**
   - StringBuilder for efficient concatenation
   - Template caching
   - Lazy evaluation

3. **Memory Optimizations**
   - Object pooling for AST nodes
   - String interning
   - Garbage collection hints

### Benchmarking

```ruby
# Performance testing
def benchmark_parser
  time = Benchmark.measure do
    100.times { Aurora.parse(large_source) }
  end
  assert time.real < 1.0
end

def benchmark_generation
  time = Benchmark.measure do
    100.times { ast.to_source }
  end
  assert time.real < 0.5
end
```

## Extension Points

### Adding New Language Features

1. **Lexer**: Add new token types
2. **Parser**: Add parsing rules
3. **AST**: Add new node types
4. **CoreIR**: Add transformations
5. **Backend**: Add C++ lowering

### Adding New C++ Features

1. **AST Nodes**: Add new node types
2. **DSL**: Add new builder methods
3. **Generator**: Add code generation logic

## Testing Architecture

### Test Categories

1. **Unit Tests**: Individual component testing
2. **Integration Tests**: End-to-end pipeline testing
3. **Performance Tests**: Benchmarking and profiling
4. **Error Tests**: Error handling and recovery testing

### Test Organization

```
test/
├── aurora/           # Aurora language tests
├── builder/          # DSL builder tests
├── integration/      # End-to-end tests
├── performance/      # Performance benchmarks
└── error_handling/  # Error handling tests
```

## Future Architecture

### Planned Improvements

1. **LLVM Backend**: Direct compilation to LLVM IR
2. **Language Server**: LSP support for IDEs
3. **Package Manager**: Dependency management
4. **Standard Library**: Built-in functions and types
5. **Debugging Support**: Source maps and debugging info

### Scalability Considerations

1. **Incremental Compilation**: Only recompile changed files
2. **Parallel Processing**: Multi-threaded compilation
3. **Caching**: Persistent compilation caches
4. **Distribution**: Distributed compilation support

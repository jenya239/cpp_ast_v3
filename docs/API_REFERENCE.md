# API Reference

## Aurora Language API

### Core Functions

#### `Aurora.parse(source, filename: nil)`
Parse Aurora source code into an AST.

```ruby
ast = Aurora.parse("fn main() -> i32 = 42")
```

#### `Aurora.compile(source, filename: nil)`
Compile Aurora source to C++ AST.

```ruby
cpp_ast = Aurora.compile("fn main() -> i32 = 42")
```

#### `Aurora.to_cpp(source, filename: nil)`
Compile Aurora source directly to C++ code.

```ruby
cpp_code = Aurora.to_cpp("fn main() -> i32 = 42")
# Returns: "int main() { return 42; }"
```

#### `Aurora.to_hpp_cpp(source, filename: nil)`
Generate header and implementation files.

```ruby
files = Aurora.to_hpp_cpp("fn main() -> i32 = 42")
# Returns: { header: "...", implementation: "..." }
```

## C++ AST DSL API

### Basic DSL Functions

#### `program(*declarations)`
Create a C++ program.

```ruby
program(
  include_directive("<iostream>"),
  function_decl("int", "main", [], block(
    return_stmt(int(42))
  ))
)
```

#### `function_decl(return_type, name, params, body)`
Create a function declaration.

```ruby
function_decl("int", "add", [
  param("int", "a"),
  param("int", "b")
], block(
  return_stmt(binary("+", id("a"), id("b")))
))
```

#### `class_decl(name, *members)`
Create a class declaration.

```ruby
class_decl("Point",
  access_spec("public"),
  var_decl("int", "x"),
  var_decl("int", "y"),
  function_decl("int", "area", [], block(
    return_stmt(binary("*", id("x"), id("y")))
  ))
)
```

### Expression DSL

#### `id(name)`
Create an identifier.

```ruby
id("variable_name")
```

#### `int(value)`, `float(value)`, `string(value)`, `bool(value)`
Create literals.

```ruby
int(42)
float(3.14)
string("hello")
bool(true)
```

#### `binary(operator, left, right)`
Create binary expressions.

```ruby
binary("+", int(1), int(2))
binary("==", id("x"), int(0))
```

#### `call(callee, *args)`
Create function calls.

```ruby
call(id("printf"), string("Hello, world!"))
```

### Statement DSL

#### `return_stmt(expr)`
Create return statements.

```ruby
return_stmt(int(42))
```

#### `var_decl(type, name, initializer = nil)`
Create variable declarations.

```ruby
var_decl("int", "x", int(42))
```

#### `block(*statements)`
Create statement blocks.

```ruby
block(
  var_decl("int", "x", int(1)),
  var_decl("int", "y", int(2)),
  return_stmt(binary("+", id("x"), id("y"))))
)
```

### Advanced Features

#### Template Support
```ruby
template_function("T", "identity", ["T"], "x", block(
  return_stmt(id("x"))
))
```

#### Modern C++ Features
```ruby
function_decl("auto", "process", [param("auto", "data")], block(
  return_stmt(call(id("std::move"), id("data")))
)).noexcept()
```

#### Inheritance
```ruby
class_with_inheritance("Derived", ["public Base"],
  function_decl("void", "override_method", []).override()
)
```

## Error Handling API

### Enhanced Error Classes

#### `Aurora::SyntaxError`
Syntax errors with suggestions.

```ruby
error = Aurora::SyntaxError.new(
  "Missing semicolon",
  location: "line 5, column 12",
  suggestion: "Add a semicolon at the end of the statement"
)
```

#### `Aurora::TypeError`
Type errors with diagnostics.

```ruby
error = Aurora::TypeError.new(
  "Type mismatch: expected int, got string",
  location: "line 3, column 8",
  suggestion: "Convert string to int or change the variable type"
)
```

#### `Aurora::ScopeError`
Scope errors with context.

```ruby
error = Aurora::ScopeError.new(
  "Undefined variable: x",
  location: "line 7, column 5",
  suggestion: "Declare the variable or check the spelling"
)
```

### Error Recovery

#### `Aurora::Parser::ErrorRecoveryParser`
Parser with error recovery capabilities.

```ruby
parser = Aurora::Parser::ErrorRecoveryParser.new(source)
begin
  ast = parser.parse
rescue Aurora::Parser::MultipleErrors => e
  e.errors.each do |error|
    puts error.formatted_message
  end
end
```

## Performance API

### Optimized Parser
```ruby
parser = Aurora::Parser::OptimizedParser.new(source)
ast = parser.parse  # Uses memoization and caching
```

### Optimized Generator
```ruby
generator = CppAst::Builder::OptimizedGenerator.new
cpp_code = generator.generate(ast)  # Uses StringBuilder and caching
```

### StringBuilder
```ruby
builder = CppAst::Builder::StringBuilder.new
builder.append("class Test {\n")
builder.indent
builder.append_indented("int value;\n")
builder.unindent
builder.append("};\n")
result = builder.to_s
```

## Utility Functions

### Formatting
```ruby
# Set formatting mode
CppAst.formatting_mode = :pretty  # or :lossless

# Use specific formatting for a block
CppAst.with_formatting_mode(:lossless) do
  # Code generation here
end
```

### AST Manipulation
```ruby
# Convert AST to DSL
dsl_code = CppAst.to_dsl(ast, indent: "  ", mode: :pretty)

# Parse C++ back to AST
ast = CppAst.parse(cpp_source)
```

## Examples

### Complete Program Generation
```ruby
require_relative "lib/cpp_ast"
include CppAst::Builder::DSL

program = program(
  include_directive("<iostream>"),
  include_directive("<vector>"),
  
  namespace("MyApp",
    class_decl("Calculator",
      access_spec("public"),
      function_decl("int", "add", [
        param("int", "a"),
        param("int", "b")
      ], block(
        return_stmt(binary("+", id("a"), id("b")))
      )),
      
      function_decl("int", "multiply", [
        param("int", "a"),
        param("int", "b")
      ], block(
        return_stmt(binary("*", id("a"), id("b")))
      ))
    ),
    
    function_decl("int", "main", [], block(
      var_decl("Calculator", "calc"),
      expr_stmt(call(id("std::cout"), 
        call(id("calc.add"), int(2), int(3)))),
      return_stmt(int(0))
    ))
  )
)

puts program.to_source
```

### Aurora to C++ Pipeline
```ruby
aurora_source = <<~AURORA
  fn factorial(n: i32) -> i32 =
    if n <= 1 then 1
    else n * factorial(n - 1)
AURORA

# Parse Aurora
ast = Aurora.parse(aurora_source)

# Transform to C++ AST
cpp_ast = Aurora.lower_to_cpp(ast)

# Generate C++ code
cpp_code = cpp_ast.to_source
puts cpp_code
```

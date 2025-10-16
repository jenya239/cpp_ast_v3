# CppAst v3 - DSL v2 Documentation

## Overview

CppAst v3 now includes **DSL v2** - a high-level, symbolic Ruby DSL for generating modern C++ code with best practices built-in. DSL v2 eliminates string literals and provides type-safe, fluent APIs for C++ code generation.

## Key Features

- **Symbolic Types**: `t.i32`, `t.f32`, `t.ref(:Type)` instead of strings
- **Fluent Expressions**: `id(:x) + id(:y)` instead of `binary("+", id("x"), id("y"))`
- **Best Practices**: Automatic `noexcept`, `[[nodiscard]]`, `const` where appropriate
- **Ownership Types**: `t.owned(:Type)`, `t.borrowed(:Type)`, `t.span(:Type)`
- **Modern C++**: Concepts, modules, coroutines, ranges support
- **Aurora/XQR**: Alternative syntax for functional programming

## Quick Start

```ruby
require_relative "lib/cpp_ast"
require_relative "lib/cpp_ast/builder/dsl_v2"

include CppAst::Builder::DSLv2

# Generate C++ code
ast = program do
  fn :calculate, 
     params: [[:f32, :x], [:f32, :y]], 
     ret: t.f32,
     constexpr: true,
     noexcept: true do
    ret id(:x) * id(:y)
  end
end

puts ast.to_node.to_source
```

## Type System

### Basic Types

```ruby
t.i32          # int
t.f32          # float
t.f64          # double
t.bool         # bool
t.void         # void
t.string       # std::string
t.char         # char
```

### Ownership Types

```ruby
t.owned(:Type)        # std::unique_ptr<Type>
t.borrowed(:Type)     # const Type&
t.mut_borrowed(:Type) # Type&
t.span(:Type)         # std::span<Type>
t.span_const(:Type)   # std::span<const Type>
```

### Container Types

```ruby
t.vec(t.f32)          # std::vector<float>
t.array(t.i32, 10)    # std::array<int, 10>
t.span(t.f32)         # std::span<float>
```

### Result/Option Types

```ruby
t.result(t.f32, t.string)  # std::expected<float, std::string>
t.option(t.i32)            # std::optional<int>
t.variant(t.Circle, t.Rect) # std::variant<Circle, Rect>
```

## Functions

### Basic Functions

```ruby
fn :add, 
   params: [[:i32, :a], [:i32, :b]], 
   ret: t.i32,
   constexpr: true,
   noexcept: true do
  ret id(:a) + id(:b)
end
```

### Member Functions

```ruby
class_ :Vec2 do
  field :x, t.f32
  field :y, t.f32
  
  def_ :length, 
       ret: t.f32, 
       const: true, 
       noexcept: true do
    ret (id(:x) * id(:x) + id(:y) * id(:y)).call(:sqrt)
  end
end
```

### Template Functions

```ruby
template_ [:T] do
  fn :max, 
     params: [[t.ref(:T, const: true), :a], [t.ref(:T, const: true), :b]], 
     ret: t.ref(:T, const: true),
     constexpr: true, 
     noexcept: true do
    if_ id(:a) > id(:b) do
      ret id(:a)
    else_
      ret id(:b)
    end
  end
end
```

## Classes

### Basic Class

```ruby
class_ :Point do
  field :x, t.f32, default: float(0.0)
  field :y, t.f32, default: float(0.0)
  
  # Automatic rule of five
  rule_of_five!
  
  # Custom constructor
  ctor params: [[:f32, :x], [:f32, :y]], 
       constexpr: true, 
       noexcept: true do
    id(:self).member(:x) = id(:x)
    id(:self).member(:y) = id(:y)
  end
end
```

### Abstract Base Class

```ruby
class_ :Shape, abstract: true do
  def_ :area, 
       ret: t.f32, 
       const: true, 
       virtual: true, 
       pure_virtual: true do
    # Pure virtual - no implementation
  end
  
  dtor virtual: true, noexcept: true do
    # Virtual destructor
  end
end
```

### Derived Class

```ruby
class_ :Circle do
  inherits :Shape, access: :public
  
  field :radius, t.f32, default: float(0.0)
  
  def_ :area, 
       ret: t.f32, 
       const: true, 
       override: true, 
       noexcept: true do
    ret float(3.14159) * id(:radius) * id(:radius)
  end
end
```

## Control Flow

### If Statements

```ruby
if_ id(:x) > float(0.0) do
  id(:result) = id(:x) * float(2.0)
elsif id(:x) < float(0.0) do
  id(:result) = id(:x) * float(-1.0)
else_
  id(:result) = float(0.0)
end
```

### Loops

```ruby
# For loop
for_ id(:i), int(0), int(10), id(:i)++ do
  id(:sum) = id(:sum) + id(:i)
end

# Range-based for loop
for_range :it, id(:container) do
  id(:sum) = id(:sum) + deref(id(:it))
end

# While loop
while_ id(:condition) do
  id(:value) = id(:value) * float(2.0)
end
```

### Pattern Matching

```ruby
match_ id(:shape) do
  case_ t.Circle, [:r] do
    ret float(3.14159) * id(:r) * id(:r)
  end
  case_ t.Rect, [:w, :h] do
    ret id(:w) * id(:h)
  end
  case_ t.Polygon, [:points] do
    ret float(0.0)  # Simplified
  end
end
```

## Expressions

### Arithmetic

```ruby
id(:x) + id(:y)        # x + y
id(:x) - id(:y)        # x - y
id(:x) * id(:y)        # x * y
id(:x) / id(:y)        # x / y
id(:x) % id(:y)        # x % y
```

### Comparisons

```ruby
id(:x) == id(:y)       # x == y
id(:x) != id(:y)       # x != y
id(:x) < id(:y)        # x < y
id(:x) <= id(:y)       # x <= y
id(:x) > id(:y)        # x > y
id(:x) >= id(:y)       # x >= y
```

### Logical

```ruby
id(:x) && id(:y)       # x && y
id(:x) || id(:y)       # x || y
!id(:x)                # !x
```

### Method Calls

```ruby
id(:obj).call(:method, id(:arg1), id(:arg2))
id(:obj).member(:field)
id(:arr)[id(:index)]
```

### Literals

```ruby
int(42)                # 42
float(3.14)            # 3.14
string("hello")        # "hello"
bool(true)             # true
char('a')              # 'a'
```

## Modern C++ Features

### Concepts

```ruby
concept_ :Sortable, [:T] do
  requires_ do
    fn :less, params: [[t.ref(:T, const: true), :a], [t.ref(:T, const: true), :b]], ret: t.bool
  end
end

template_ [:T] do
  fn :sort, 
     params: [[t.span(t.ref(:T, mutable: true)), :arr]], 
     ret: t.void,
     requires: concept(:Sortable, :T),
     noexcept: true do
    # Sort implementation
  end
end
```

### Modules (C++20)

```ruby
module_ "app.geom" do
  export_ do
    struct_ :Vec2 do
      field :x, t.f32
      field :y, t.f32
    end
    
    fn :length, 
       params: [[t.ref(:Vec2, const: true), :v]], 
       ret: t.f32,
       constexpr: true, 
       noexcept: true do
      ret (id(:v).member(:x) * id(:v).member(:x) + 
           id(:v).member(:y) * id(:v).member(:y)).call(:sqrt)
    end
  end
end
```

### Coroutines

```ruby
async_fn :fetch_data, 
         params: [[t.string, :url]], 
         ret: t.Task(t.string) do
  let_ :data, co_await(call(:http_get, id(:url)))
  co_return id(:data)
end
```

## Aurora/XQR Syntax

Aurora provides a functional programming syntax that compiles to C++:

```aurora
module app/geom

type Vec2 = { x: f32, y: f32 }

fn length(v: Vec2) -> f32 =
  (v.x*v.x + v.y*v.y).sqrt()

fn scale(v: Vec2, k: f32) -> Vec2 =
  { x: v.x*k, y: v.y*k }
```

## Examples

See the `examples/dsl_v2/` directory for comprehensive examples:

- `01_basic_types.rb` - Basic types and expressions
- `02_functions.rb` - Functions with best practices
- `03_classes.rb` - Classes with rule of five
- `04_ownership.rb` - Ownership types and memory management
- `05_aurora_syntax.rb` - Aurora/XQR syntax examples
- `06_modern_cpp.rb` - Modern C++ features

## Migration from DSL v1

DSL v1 (string-based) remains supported for backward compatibility:

```ruby
# v1 (old) - still works
function_decl("int", "foo", ["int a"], block(...))

# v2 (new) - recommended
fn :foo, params: [[:i32, :a]], ret: t.i32 do
  ...
end
```

## Best Practices

1. **Use symbolic types**: `t.i32` instead of `"int"`
2. **Leverage automatic best practices**: `noexcept`, `[[nodiscard]]`, `const`
3. **Use ownership types**: `t.owned(:Type)`, `t.borrowed(:Type)`
4. **Apply rule of five**: `rule_of_five!` for classes
5. **Use concepts**: For template constraints
6. **Prefer constexpr**: For compile-time evaluation
7. **Use noexcept**: For exception safety

## Performance

DSL v2 generates optimized C++ code with:
- Automatic `constexpr` where possible
- `noexcept` for exception safety
- Move semantics for performance
- RAII for resource management
- Modern C++ features (concepts, modules, coroutines)

## Conclusion

DSL v2 provides a modern, type-safe, and expressive way to generate C++ code while maintaining best practices and performance. It eliminates the verbosity of string-based DSLs while providing powerful abstractions for modern C++ development.

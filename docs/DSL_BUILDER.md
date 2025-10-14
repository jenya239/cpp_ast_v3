# DSL Builder для C++ AST

Ruby DSL для программного создания C++ AST с поддержкой bidirectional трансформации.

## Использование

### Создание AST через DSL

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

### Генерация DSL кода из C++

```ruby
require "cpp_ast"

cpp_code = <<~CPP
  int main(){
  return 0;
  }
CPP

ast = CppAst.parse(cpp_code)
dsl_code = CppAst.to_dsl(ast)

puts dsl_code
# => program(
#      function_decl("int", "main", [],
#        block(
#        return_stmt(int(0)),
#      )
#      )
#      .with_rparen_suffix(""),
#    )
```

### Roundtrip: C++ → DSL → C++

```ruby
include CppAst::Builder::DSL

cpp_original = "int main(){\nreturn 0;\n}\n"

# Parse to AST
ast1 = CppAst.parse(cpp_original)

# Generate DSL code
dsl_code = CppAst.to_dsl(ast1)

# Eval DSL to get AST back
ast2 = eval(dsl_code)

# Generate C++ again
cpp_result = ast2.to_source

cpp_original == cpp_result  # => true (perfect roundtrip!)
```

## API

### Literals
- `int(42)` - целочисленный литерал
- `float(3.14)` - float литерал
- `string('"hello"')` - строковый литерал (с кавычками)
- `char("'a'")` - char литерал (с одинарными кавычками)

### Identifiers
- `id("x")` - идентификатор

### Expressions
- `binary("+", left, right)` - бинарная операция
- `unary("-", expr)` - унарная операция (prefix)
- `unary_post("++", expr)` - унарная операция (postfix)
- `paren(expr)` - выражение в скобках
- `call(callee, *args)` - вызов функции
- `member(obj, ".", "field")` - доступ к члену (`.`, `->`, `::`)
- `subscript(arr, idx)` - индексация массива
- `ternary(cond, true_expr, false_expr)` - тернарный оператор

### Statements
- `expr_stmt(expr)` - expression statement
- `return_stmt(expr)` - return statement
- `block(*stmts)` - блок с statements
- `if_stmt(cond, then_branch, else_branch=nil)` - if/else
- `while_stmt(cond, body)` - while loop
- `for_stmt(init, cond, inc, body)` - for loop
- `break_stmt` - break
- `continue_stmt` - continue

### Declarations
- `var_decl(type, *declarators)` - объявление переменной
- `function_decl(ret_type, name, params, body=nil)` - объявление функции
- `namespace_decl(name, body)` - namespace
- `class_decl(name, members)` - class
- `struct_decl(name, members)` - struct

### Program
- `program(*stmts)` - корневой узел

## Fluent API для Trivia

Все ноды поддерживают fluent API для установки trivia параметров:

```ruby
# Default spacing
ast = function_decl("int", "main", [],
  block(return_stmt(int(0)))
)

# Custom spacing with fluent API
ast = function_decl("int", "main", [],
  block(return_stmt(int(0)))
    .with_lbrace_suffix("\n  ")
    .with_rbrace_prefix("\n")
).with_rparen_suffix("")

# Chain multiple fluent calls
expr = binary("+", int(1), int(2))
  .with_operator_prefix("")
  .with_operator_suffix("")
# Result: "1+2" (без пробелов)
```

### Доступные Fluent методы

**Statements** (все):
- `.with_leading(trivia)` - установить leading trivia

**BinaryExpression**:
- `.with_operator_prefix(trivia)`
- `.with_operator_suffix(trivia)`

**UnaryExpression**:
- `.with_operator_suffix(trivia)`

**FunctionCallExpression**:
- `.with_lparen_suffix(trivia)`
- `.with_rparen_prefix(trivia)`
- `.with_argument_separators(array)`

**BlockStatement**:
- `.with_lbrace_suffix(trivia)`
- `.with_rbrace_prefix(trivia)`
- `.with_statement_trailings(array)`

**FunctionDeclaration**:
- `.with_return_type_suffix(trivia)`
- `.with_rparen_suffix(trivia)`
- `.with_param_separators(array)`

И другие... (см. `lib/cpp_ast/builder/fluent.rb`)

## Roundtrip тестирование

### DSL → AST → C++ → Parser → AST

Стратегия: DSL → AST → C++ код → Parser → AST → сравнение

```ruby
ast1 = program(return_stmt(int(42)))
cpp = ast1.to_source
ast2 = CppAst.parse(cpp)
assert_equal cpp, ast2.to_source
```

Тесты в `test/builder/roundtrip_test.rb`

### C++ → Parser → AST → DSL → eval → AST → C++

Полный bidirectional roundtrip:

```ruby
cpp_original = "int main(){\nreturn 0;\n}\n"

# Parse C++ → AST
ast1 = CppAst.parse(cpp_original)

# AST → DSL code
dsl_code = CppAst.to_dsl(ast1)

# Eval DSL → AST
ast2 = eval(dsl_code)

# AST → C++
cpp_result = ast2.to_source

cpp_original == cpp_result  # => true!
```

Тесты в `test/builder/dsl_generator_test.rb` (34 тестов, все проходят)

## Aurora DSL Extensions

### Ownership Types

```ruby
owned("Vec2")        # std::unique_ptr<Vec2>
borrowed("Vec2")     # const Vec2&
mut_borrowed("Vec2") # Vec2&
span_of("int")       # std::span<int>

# Helper для параметров
param(owned("Resource"), "resource")
param(borrowed("Config"), "config")
```

### Result/Option Types

```ruby
result_of("int", "std::string")  # std::expected<int, std::string>
option_of("float")               # std::optional<float>

# Конструкторы
ok(value)      # std::expected<T, E>::value_type
err(error)     # std::expected<T, E>::error_type
some(value)    # std::optional<T>::value_type
none()         # std::optional<T>::nullopt
```

### Product Types (Structs)

```ruby
product_type("Point",
  field_def("x", "float"),
  field_def("y", "float")
)
# => struct Point { float x; float y; };
```

### Sum Types (Variants)

```ruby
sum_type("Shape",
  case_struct("Circle", field_def("r", "float")),
  case_struct("Rect", field_def("w", "float"), field_def("h", "float"))
)
# => struct Circle { float r; };
#    struct Rect { float w; float h; };
#    using Shape = std::variant<Circle, Rect>;
```

### Pattern Matching

```ruby
match_expr(id("shape"),
  arm("Circle", ["r"], 
    binary("*", float(3.14), binary("*", id("r"), id("r")))
  ),
  arm("Rect", ["w", "h"], 
    binary("*", id("w"), id("h"))
  )
)
# => std::visit(overloaded{...}, shape)
```

### Полный пример

```ruby
# Product type
product_type("Point",
  field_def("x", "float"),
  field_def("y", "float")
)

# Sum type
sum_type("Shape",
  case_struct("Circle", 
    field_def("center", "Point"),
    field_def("radius", "float")
  ),
  case_struct("Rect",
    field_def("top_left", "Point"),
    field_def("width", "float"),
    field_def("height", "float")
  )
)

# Функция с pattern matching
function_decl(
  result_of("float", "std::string"),
  "calculate_area",
  [param(borrowed("Shape"), "shape")],
  block(
    return_stmt(
      match_expr(id("shape"),
        arm("Circle", ["center", "radius"],
          binary("*", float(3.14159), binary("*", id("radius"), id("radius")))
        ),
        arm("Rect", ["top_left", "width", "height"],
          binary("*", id("width"), id("height"))
        )
      )
    )
  )
)
```

См. `docs/AURORA_DSL.md` для полной документации Aurora DSL.

## Ограничения

- Строковые литералы передаются "как есть" (с кавычками): `string('"hello"')`
- Char литералы передаются "как есть" (с одинарными кавычками): `char("'a'")`
- Параметры функций передаются как строки: `["int a", "int b"]`
- Declarators передаются как строки: `"x = 42"`
- Trivia генерируется автоматически (минималистично)


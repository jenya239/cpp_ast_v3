# Aurora DSL - Современный C++ через Ruby

Aurora DSL расширяет базовый DSL Builder современными C++ конструкциями: ownership, ADT, pattern matching, и Result/Option типами.

## Обзор

Aurora DSL позволяет генерировать современный C++20/23 код с лучшими практиками:
- **Ownership**: `std::unique_ptr`, `const T&`, `T&`, `std::span`
- **ADT**: Product типы (struct), Sum типы (variant)
- **Pattern Matching**: `std::visit` с `overloaded`
- **Result/Option**: `std::expected`, `std::optional`

## Ownership Types

### Базовые ownership типы

```ruby
owned("Vec2")        # std::unique_ptr<Vec2>
borrowed("Vec2")     # const Vec2&
mut_borrowed("Vec2") # Vec2&
span_of("int")       # std::span<int>
```

### Примеры использования

```ruby
# Функция с ownership параметрами
function_decl(
  "void",
  "process_vectors",
  [
    param(span_of(owned("Vec2")), "vectors"),
    param(borrowed("Config"), "config")
  ],
  block(
    # Тело функции
  )
)
```

**Генерирует**:
```cpp
void process_vectors(std::span<std::unique_ptr<Vec2>> vectors, const Config& config) {
  // Тело функции
}
```

### Helper методы

```ruby
# Создание параметра с типом
param("std::unique_ptr<Vec2>", "vec")  # Строковый тип
param(owned("Vec2"), "vec")            # DSL тип

# Dereference оператор
deref(id("ptr"))  # *ptr
```

## Result/Option Types

### Базовые типы

```ruby
result_of("int", "std::string")  # std::expected<int, std::string>
option_of("int")                 # std::optional<int>
```

### Конструкторы

```ruby
ok(value)      # std::expected<T, E>::value_type
err(error)     # std::expected<T, E>::error_type
some(value)    # std::optional<T>::value_type
none()         # std::optional<T>::nullopt
```

### Примеры

```ruby
# Функция возвращающая Result
function_decl(
  result_of("float", "std::string"),
  "safe_divide",
  [param("float", "a"), param("float", "b")],
  block(
    if_stmt(
      binary("==", id("b"), float(0.0)),
      block(return_stmt(err(string('"Division by zero"')))),
      block(return_stmt(ok(binary("/", id("a"), id("b")))))
    )
  )
)
```

**Генерирует**:
```cpp
std::expected<float, std::string> safe_divide(float a, float b) {
  if (b == 0.0) {
    return std::move("Division by zero");
  } else {
    return std::move(a / b);
  }
}
```

## Product Types

Product типы представляют структуры данных с несколькими полями.

### Базовый синтаксис

```ruby
product_type("Point",
  field_def("x", "float"),
  field_def("y", "float")
)
```

**Генерирует**:
```cpp
struct Point {
  float x;
  float y;
};
```

### Сложные типы

```ruby
product_type("Config",
  field_def("width", "int"),
  field_def("height", "int"),
  field_def("title", "std::string"),
  field_def("enabled", "bool")
)
```

### Использование в функциях

```ruby
# Функция принимающая product тип
function_decl(
  "float",
  "distance",
  [
    param("Point", "p1"),
    param("Point", "p2")
  ],
  block(
    return_stmt(
      call(id("sqrt"),
        binary("+",
          binary("*", 
            binary("-", member(id("p1"), ".", "x"), member(id("p2"), ".", "x")),
            binary("-", member(id("p1"), ".", "x"), member(id("p2"), ".", "x"))
          ),
          binary("*",
            binary("-", member(id("p1"), ".", "y"), member(id("p2"), ".", "y")),
            binary("-", member(id("p1"), ".", "y"), member(id("p2"), ".", "y"))
          )
        )
      )
    )
  )
)
```

## Sum Types

Sum типы представляют алгебраические типы данных с несколькими вариантами.

### Базовый синтаксис

```ruby
sum_type("Shape",
  case_struct("Circle", field_def("r", "float")),
  case_struct("Rect", field_def("w", "float"), field_def("h", "float"))
)
```

**Генерирует**:
```cpp
struct Circle {
  float r;
};
struct Rect {
  float w;
  float h;
};
using Shape = std::variant<Circle, Rect>;
```

### Сложные sum типы

```ruby
sum_type("Expression",
  case_struct("Number", field_def("value", "float")),
  case_struct("Add", 
    field_def("left", "std::unique_ptr<Expression>"),
    field_def("right", "std::unique_ptr<Expression>")
  ),
  case_struct("Variable", field_def("name", "std::string"))
)
```

## Pattern Matching

Pattern matching позволяет обрабатывать sum типы через `std::visit`.

### Базовый синтаксис

```ruby
match_expr(id("shape"),
  arm("Circle", ["r"], 
    binary("*", float(3.14159), binary("*", id("r"), id("r")))
  ),
  arm("Rect", ["w", "h"], 
    binary("*", id("w"), id("h"))
  )
)
```

**Генерирует**:
```cpp
std::visit(overloaded{
  [&](const Circle& circle) { 
    auto [r] = circle; 
    return 3.14159 * r * r; 
  },
  [&](const Rect& rect) { 
    auto [w, h] = rect; 
    return w * h; 
  }
}, shape)
```

### Сложные pattern matching

```ruby
# Функция с pattern matching
function_decl(
  "float",
  "calculate_area",
  [param("Shape", "shape")],
  block(
    return_stmt(
      match_expr(id("shape"),
        arm("Circle", ["r"], 
          binary("*", float(3.14159), binary("*", id("r"), id("r")))
        ),
        arm("Rect", ["w", "h"], 
          binary("*", id("w"), id("h"))
        ),
        arm("Polygon", ["points"], 
          float(0.0)  # Сложный расчет площади
        )
      )
    )
  )
)
```

## Комбинированные примеры

### Полный пример: Геометрические фигуры

```ruby
# Product типы
product_type("Point",
  field_def("x", "float"),
  field_def("y", "float")
)

# Sum типы
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

# Функция с ownership и pattern matching
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

# Функция обработки коллекции
function_decl(
  "void",
  "process_shapes",
  [param(span_of(owned("Shape")), "shapes")],
  block(
    for_stmt(
      "auto it = shapes.begin()",
      binary("!=", id("it"), call(member(id("shapes"), ".", "end"))),
      unary_post("++", id("it")),
      block(
        expr_stmt(
          call(id("process_shape"), deref(id("it")))
        )
      )
    )
  )
)
```

## Best Practices

### 1. Используйте ownership правильно

```ruby
# ✅ Хорошо: явное ownership
param(owned("Resource"), "resource")
param(borrowed("Config"), "config")

# ❌ Плохо: неявные типы
param("Resource", "resource")  # Неясно, кто владеет
```

### 2. Комбинируйте типы осмысленно

```ruby
# ✅ Хорошо: Result с Option
result_of(option_of("float"), "std::string")

# ✅ Хорошо: Span с owned элементами
span_of(owned("Shape"))
```

### 3. Используйте pattern matching для sum типов

```ruby
# ✅ Хорошо: явный pattern matching
match_expr(id("expr"),
  arm("Number", ["value"], id("value")),
  arm("Add", ["left", "right"], 
    binary("+", id("left"), id("right"))
  )
)
```

## Совместимость с C++

### Требования компилятора

- **C++20**: `std::span`, `std::expected` (или `tl::expected`)
- **C++17**: `std::optional`, `std::variant`
- **C++11**: `std::unique_ptr`

### Fallback для старых стандартов

```ruby
# Для C++17 без std::expected
# Используйте tl::expected или собственную реализацию
```

## Отладка

### Проверка сгенерированного кода

```ruby
ast = your_aurora_dsl_code
puts ast.to_source
```

### Тестирование

```ruby
# Roundtrip тест
original_ast = your_aurora_dsl_code
cpp_code = original_ast.to_source
parsed_ast = CppAst.parse(cpp_code)
puts "Roundtrip successful: #{original_ast.to_source == parsed_ast.to_source}"
```

## Заключение

Aurora DSL предоставляет мощные инструменты для генерации современного C++ кода с лучшими практиками. Используйте ownership, ADT и pattern matching для создания безопасного и выразительного кода.

<!-- 2af3d07b-a7d4-4d56-b70f-be6f5555c069 ad0037ff-387d-4a3f-a054-4ff53f80417c -->
# Доработка cppastv3: High-Level Ruby DSL + Aurora/XQR

## Обзор изменений

Трансформация cpp_ast_v3 в полноценный инструмент генерации современного C++ через:

1. Высокоуровневый Ruby DSL без строковых литералов (только символы)
2. Best practices по умолчанию
3. Язык Aurora/XQR поверх CppAst
4. Типобезопасный Builder API

---

## Фаза 1: Символьный DSL (вместо строк)

### 1.1 Type System DSL

**Файл**: `lib/cpp_ast/builder/types_dsl.rb`

Заменить строковые типы на символьный API:

```ruby
# Сейчас:
function_decl("int", "foo", ["int a"], ...)

# Станет:
fn :foo, params: [[:i32, :a]], ret: t.i32 do
  ...
end
```

**Реализация**:

- Модуль `TypesDSL` с методами `t.i32`, `t.f32`, `t.void`, `t.ref(type)`, `t.span(type)`
- Маппинг символов в C++ типы: `:i32 → "int"`, `:f32 → "float"`
- Поддержка квалификаторов: `t.ref(:i32, const: true)` → `const int&`

### 1.2 Expression Builder

**Файл**: `lib/cpp_ast/builder/expr_builder.rb`

Fluent API для выражений:

```ruby
# Сейчас:
binary("+", id("a"), id("b"))

# Станет:
id(:a) + id(:b)  # или e.add(id(:a), id(:b))
```

**Реализация**:

- `ExprNode` с операторами `+`, `*`, `/`, etc
- Chain-методы: `.call(:method, args)`, `.member(:field)`
- Pipe operator: `e.pipe(id(:x), :sqrt)` → `x |> sqrt`

### 1.3 Control Flow DSL

**Файл**: `lib/cpp_ast/builder/control_dsl.rb`

```ruby
# Сейчас:
if_stmt(cond, then_block, else_block)

# Станет:
if_ cond do
  ...
elsif other_cond do
  ...
else_
  ...
end
```

---

## Фаза 2: Best Practices Builder

### 2.1 Function Builder с умолчаниями

**Файл**: `lib/cpp_ast/builder/function_builder.rb`

```ruby
fn :calculate, 
   params: [[:f32, :x], [:f32, :y]], 
   ret: t.f32,
   const: true,           # const по умолчанию где можно
   noexcept: true,        # добавляем автоматически
   nodiscard: true do     # [[nodiscard]] по умолчанию
  ret id(:x) * id(:y)
end
```

**Умолчания**:

- `noexcept` для pure functions
- `[[nodiscard]]` для не-void функций
- `const` для методов без мутаций
- `constexpr` где возможно

### 2.2 Class Builder

**Файл**: `lib/cpp_ast/builder/class_builder.rb`

```ruby
class_ :Vec2, final: true do
  field :x, t.f32, default: 0.0
  field :y, t.f32, default: 0.0
  
  ctor params: [[:f32, :x], [:f32, :y]], 
       constexpr: true, 
       noexcept: true
  
  def_ :length, ret: t.f32, const: true, noexcept: true do
    ret (id(:x)*id(:x) + id(:y)*id(:y)).call(:sqrt)
  end
  
  rule_of_five! # генерирует конструкторы автоматически
end
```

### 2.3 Ownership Types

**Файл**: `lib/cpp_ast/builder/ownership_dsl.rb`

```ruby
t.owned(:Buffer)        # std::unique_ptr<Buffer>
t.borrowed(:Config)     # const Config&
t.mut_borrowed(:State)  # State&
t.span_of(t.f32)       # std::span<float>
```

---

## Фаза 3: Aurora Language Layer

### 3.1 Aurora Parser

**Файл**: `lib/aurora/parser/aurora_parser.rb`

Parslet-based парсер Aurora синтаксиса:

```aurora
module app/geom

type Vec2 = { x: f32, y: f32 }

fn length(v: Vec2) -> f32 =
  (v.x*v.x + v.y*v.y).sqrt()
```

**Грамматика**:

- Module declaration
- Type declarations (record, sum, alias)
- Function declarations
- Expressions (let, if, match, call, literals)

### 3.2 Aurora AST

**Файл**: `lib/aurora/ast/aurora_nodes.rb`

Отдельный AST для Aurora (расширить текущий):

```ruby
Aurora::AST::Module(name, decls)
Aurora::AST::TypeRecord(name, fields)
Aurora::AST::TypeSum(name, variants)
Aurora::AST::Fn(name, params, ret, body)
Aurora::AST::Expr::Match(value, arms)
Aurora::AST::Expr::Pipe(lhs, rhs)
```

### 3.3 Aurora → CppAst Lowering

**Файл**: `lib/aurora/backend/aurora_lowering.rb`

Улучшить существующий lowering:

```ruby
Aurora::AST::TypeRecord → CppAst::Nodes::StructDeclaration
Aurora::AST::TypeSum → variant + case structs
Aurora::AST::Expr::Match → std::visit
Aurora::AST::Expr::Pipe → nested calls
```

**Добавить**:

- Pattern matching → std::visit + overloaded
- Guards в match → if внутри lambda
- Record updates → struct constructor
- Array literals → std::array или std::vector

---

## Фаза 4: Modern C++ Features

### 4.1 Concepts Builder

**Файл**: `lib/cpp_ast/builder/concepts_dsl.rb`

```ruby
concept_ :Sortable, [:T] do
  requires_ do
    fn :less, params: [[t.ref(:T), :a], [t.ref(:T), :b]], ret: t.bool
  end
end

fn :sort, generics: [:T], requires: concept(:Sortable, :T) do
  ...
end
```

### 4.2 Modules (C++20)

**Файл**: `lib/cpp_ast/builder/modules_dsl.rb`

```ruby
module_ "app.geom" do
  export_ {
    struct_ :Vec2 do ... end
    fn :length do ... end
  }
end
```

### 4.3 Coroutines

**Файл**: `lib/cpp_ast/builder/coroutines_dsl.rb`

```ruby
async_fn :fetch, ret: t.task(t.string) do
  let_ :data, co_await(call(:read_async))
  co_return id(:data)
end
```

---

## Фаза 5: Tooling

### 5.1 DSL Templates

**Файл**: `lib/cpp_ast/templates/`

Готовые шаблоны:

```ruby
# lib/cpp_ast/templates/service.rb
service :MyService do
  singleton!
  
  method :process, params: [[t.span(:byte), :data]], ret: t.result(:void) do
    ...
  end
end
```

### 5.2 Policy System

**Файл**: `lib/cpp_ast/builder/policies.rb`

Конфигурируемые политики:

```ruby
CppAst.with_policy(:strict_safety) do
  # noexcept везде
  # [[nodiscard]] на всё не-void
  # delete copy constructors по умолчанию
end

CppAst.with_policy(:embedded) do
  # no exceptions
  # no RTTI
  # static allocation
end
```

### 5.3 Macro System

**Файл**: `lib/cpp_ast/builder/macros.rb`

Ruby-макросы для генерации шаблонного кода:

```ruby
generate_enum_flags :MyFlags, [:Read, :Write, :Execute]
# → enum class + операторы | & ~

generate_visitor :Shape, [:Circle, :Rect, :Polygon]
# → std::visit boilerplate
```

---

## Фаза 6: Documentation & Examples

### 6.1 Обновить README

- Новые примеры с символьным DSL
- Quick start guide
- Migration guide от старого DSL

### 6.2 Добавить примеры

**Папка**: `examples/dsl_v2/`

- `01_basic_types.rb` - типы через t.
- `02_functions.rb` - fn с best practices
- `03_classes.rb` - class_ с rule_of_five
- `04_ownership.rb` - owned/borrowed
- `05_aurora_syntax.rb` - Aurora → C++
- `06_modern_cpp.rb` - concepts, modules, coroutines

### 6.3 Tests

**Папка**: `test/builder/dsl_v2/`

Тесты для каждой новой фичи DSL

---

## Структура файлов

```
lib/
├── cpp_ast/
│   ├── builder/
│   │   ├── types_dsl.rb          # NEW: t.i32, t.ref, etc
│   │   ├── expr_builder.rb       # NEW: fluent expressions
│   │   ├── control_dsl.rb        # NEW: if_/while_/for_
│   │   ├── function_builder.rb   # NEW: fn with policies
│   │   ├── class_builder.rb      # NEW: class_ with helpers
│   │   ├── ownership_dsl.rb      # NEW: owned/borrowed
│   │   ├── concepts_dsl.rb       # NEW: concept_/requires_
│   │   ├── modules_dsl.rb        # NEW: module_/export_
│   │   ├── coroutines_dsl.rb     # NEW: async_fn/co_*
│   │   ├── policies.rb           # NEW: политики генерации
│   │   └── macros.rb             # NEW: Ruby макросы
│   ├── templates/                # NEW: готовые шаблоны
│   │   ├── service.rb
│   │   ├── singleton.rb
│   │   └── enum_flags.rb
│   └── ... (existing)
├── aurora/
│   ├── parser/
│   │   └── aurora_parser.rb      # IMPROVED: parslet parser
│   ├── ast/
│   │   └── aurora_nodes.rb       # IMPROVED: полный AST
│   └── backend/
│       └── aurora_lowering.rb    # IMPROVED: match, pipes
└── xqr.rb                        # NEW: alias для aurora.rb
```

---

## Приоритеты

### Критично (1-2 недели)

- Фаза 1: Символьный DSL
- Фаза 2: Best practices builder
- Документация и примеры

### Важно (2-3 недели)

- Фаза 3: Aurora parser + lowering
- Фаза 4.1: Concepts
- Policy system

### Опционально (1-2 месяца)

- Фаза 4.2-4.3: Modules, Coroutines
- Macro system
- Advanced templates

---

## Обратная совместимость

Старый DSL остаётся рабочим:

```ruby
# v1 (старый) - работает
function_decl("int", "foo", ["int a"], block(...))

# v2 (новый) - рекомендуется
fn :foo, params: [[:i32, :a]], ret: t.i32 do
  ...
end
```

Добавить deprecation warnings для строковых API.

---

## Итоговый результат

После всех фаз получим:

1. **High-level Ruby DSL** без строк, с типобезопасностью
2. **Best practices** встроены по умолчанию
3. **Aurora/XQR** как альтернативный синтаксис
4. **Modern C++** поддержка (concepts, modules, coroutines)
5. **Готовые шаблоны** для типовых задач
6. **Конфигурируемые политики** генерации

Проект станет production-ready инструментом для генерации современного C++ кода через выразительный Ruby DSL или минималистичный синтаксис Aurora/XQR.

### To-dos

- [x] Фаза 1.1: Создать TypesDSL модуль (t.i32, t.f32, t.ref, t.span)
- [x] Фаза 1.2: Создать ExprBuilder с операторами и chain-методами
- [x] Фаза 1.3: Создать ControlDSL (if_/while_/for_ с блоками)
- [x] Фаза 2.1: Function Builder с best practices (noexcept, nodiscard)
- [x] Фаза 2.2: Class Builder с rule_of_five и умолчаниями
- [x] Фаза 2.3: Ownership types (owned/borrowed/span)
- [x] Фаза 3.1: XQR модуль как алиас для Aurora
- [x] Фаза 4.1: Modern C++ features (concepts, modules, coroutines)
- [x] Фаза 6.2: Добавить примеры dsl_v2 (6 файлов)
- [x] Фаза 6.1: Обновить README с новым DSL и migration guide
- [ ] Фаза 6.3: Написать полные тесты для DSL v2
- [ ] Фаза 6.4: Создать тесты для Aurora/XQR
- [ ] Фаза 6.5: Создать интеграционные тесты
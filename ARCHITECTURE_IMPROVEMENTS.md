# Aurora Compiler: Architecture Improvements Analysis

**Date**: 2025-10-31
**Status**: After completing rules-based refactoring

## Критические проблемы (обнаружены при тестировании реального кода)

###  1. 🔴 КРИТИЧЕСКИЙ БАГ: Обрывается тело функции с множественными statements
**Симптом**: Функция `main()` генерирует только первый statement, остальное тело теряется
```cpp
constexpr int main() noexcept{
  return aurora::io::println(aurora::String("=== Testing Result type with division ==="));
}
// ВСЕ ОСТАЛЬНЫЕ 10+ СТРОК ПОТЕРЯНЫ!
```

**Причина**: Вероятно проблема в трансформации BlockExpr с несколькими statements
**Приоритет**: НЕМЕДЛЕННО ИСПРАВИТЬ
**Файл**: `lib/aurora/passes/to_core/expression_transformer.rb` или соответствующее правило

### 2. 🔴 КРИТИЧЕСКИЙ БАГ: Неправильная генерация generic variant types
**Симптом**:
```cpp
template<typename T, typename E>
struct Ok {T field0;};
template<typename T, typename E>
struct Err {E field0;};
template<typename T, typename E>
using Result = std::variant<Ok, Err>;  // ❌ WRONG! Должно быть Ok<T,E>, Err<T,E>
```

**Причина**: Type lowering не добавляет type parameters при использовании в variant
**Приоритет**: КРИТИЧЕСКИЙ
**Файл**: `lib/aurora/backend/cpp_lowering/type_lowerer.rb`

### 3. 🟡 Генерация constexpr для IO функций
**Симптом**:
```cpp
constexpr int main() noexcept{
  return aurora::io::println(...); // ❌ Warning: println не constexpr
}
```

**Причина**: EffectAnalyzer не проверяет вызовы IO функций
**Приоритет**: ВЫСОКИЙ
**Файл**: `lib/aurora/type_system/effect_analyzer.rb`

### 4. 🟡 Избыточные IIFE для простых if expressions
**Симптом**:
```cpp
return b == 0 ? [&]() { return Err(...); }() : [&]() { return Ok(...); }()
// Должно быть просто:
return b == 0 ? Err(...) : Ok(...)
```

**Причина**: RuntimePolicy или if expression lowering всегда создает IIFE
**Приоритет**: СРЕДНИЙ (производительность)
**Файл**: `lib/aurora/backend/cpp_lowering/expression_lowerer.rb` или `IfRule`

---

## Архитектурные проблемы

### 1. 🔴 Использование `transformer.send(:private_method)` в правилах

**Проблема**: 25 файлов правил используют `transformer.send` для вызова приватных методов

**Последствия**:
- Нарушение инкапсуляции
- Правила зависят от внутренних деталей трансформера
- Невозможно протестировать правила независимо
- Сложно рефакторить трансформеры

**Примеры использования**:
```ruby
# Рекурсивная трансформация
transformer.send(:transform_expression, node.body)
transformer.send(:transform_block_expr, block)

# Type inference
transformer.send(:infer_type, node.name)
transformer.send(:ensure_compatible_type, type1, type2)

# State management
transformer.send(:current_lambda_param_types)
transformer.send(:current_type_params)

# Predicates
transformer.send(:unit_branch_ast?, node.branch)
```

**Решение**: Создать отдельные сервисы и передавать через context:
```ruby
# До (плохо)
type = transformer.send(:infer_type, node.name)

# После (хорошо)
type_inferrer = context[:type_inferrer]
type = type_inferrer.infer(node.name)
```

### 2. 🔴 Трансформеры не нужны - вся логика должна быть в правилах

**Текущая архитектура**:
```
Rule (applies? + apply) → вызывает → Transformer (содержит всю логику)
```

**Проблема**: Правила - просто прослойка, реальная работа в трансформерах

**Идеальная архитектура** (как в LLVM/MLIR):
```
PassManager → Pass (множество правил) → Services (чистые функции)
```

**Что делать**:
1. Создать сервисы: `TypeInferrer`, `ExpressionBuilder`, `TypeChecker`
2. Передавать сервисы через context в правила
3. Удалить трансформеры как классы (оставить только как координаторы)
4. Вся логика - в правилах

### 3. 🟡 Отсутствие Visitor pattern

**Текущий код** (в трансформерах):
```ruby
def transform_expression(node)
  case node
  when AST::IntLit then ...
  when AST::BinaryOp then ...
  when AST::Call then ...
  # 20+ веток
  end
end
```

**Проблема**: Нарушает Open/Closed Principle, сложно расширять

**Решение**: Double dispatch через Visitor
```ruby
class ExpressionVisitor
  def visit(node)
    node.accept(self)
  end

  def visit_int_lit(node); ...; end
  def visit_binary_op(node); ...; end
end

# В AST nodes
class IntLit
  def accept(visitor)
    visitor.visit_int_lit(self)
  end
end
```

### 4. 🟡 Отсутствие Builder pattern для CoreIR

**Текущий код**:
```ruby
CoreIR::BinaryExpr.new(
  op: node.op,
  left: left_expr,
  right: right_expr,
  type: result_type
)
```

**Проблема**: Много повторяющегося кода, легко забыть параметры

**Решение**: Fluent Builder
```ruby
CoreIRBuilder.new
  .binary_expr(node.op)
  .left(left_expr)
  .right(right_expr)
  .with_type(result_type)
  .build
```

---

## Что не хватает по сравнению с большими языками

### 1. ❌ Traits / Type Classes (как в Rust/Haskell)
```aurora
// ЖЕЛАЕМО:
trait Numeric {
  fn add(self, other: Self) -> Self
  fn mul(self, other: Self) -> Self
}

impl Numeric for i32 { ... }
impl Numeric for f32 { ... }

fn sum<T: Numeric>(a: T, b: T) -> T = a.add(b)
```

**Важность**: КРИТИЧЕСКАЯ для полиморфизма
**Сложность**: ВЫСОКАЯ (требует type system redesign)

### 2. ❌ Mutable variables (let mut)
```aurora
// СЕЙЧАС НЕ РАБОТАЕТ:
fn sum_array(arr: [i32]) -> i32 =
  let mut total = 0
  for x in arr do
    total = total + x
  total
```

**Важность**: КРИТИЧЕСКАЯ для императивного кода
**Сложность**: СРЕДНЯЯ (требует SSA/phi nodes в IR)

### 3. ❌ Ownership & Borrowing (как в Rust)
```aurora
// ЖЕЛАЕМО:
fn process(data: &mut Data) -> ()  // borrow reference
fn consume(data: Data) -> ()       // move ownership
```

**Важность**: СРЕДНЯЯ (для безопасности памяти)
**Сложность**: ОЧЕНЬ ВЫСОКАЯ

### 4. ❌ Async/Await
```aurora
// ЖЕЛАЕМО:
async fn fetch_data(url: string) -> Result<Data, Error> = ...
fn main() -> i32 = await fetch_data("http://...")
```

**Важность**: СРЕДНЯЯ (для современных приложений)
**Сложность**: ОЧЕНЬ ВЫСОКАЯ

### 5. ❌ Macro system / Metaprogramming
```aurora
// ЖЕЛАЕМО:
macro println!(fmt, ...) { ... }
```

**Важность**: НИЗКАЯ (nice to have)
**Сложность**: ВЫСОКАЯ

### 6. ❌ Package Manager
**Важность**: ВЫСОКАЯ (для экосистемы)
**Сложность**: СРЕДНЯЯ

### 7. ❌ Language Server Protocol (LSP)
**Важность**: КРИТИЧЕСКАЯ (для adoption)
**Сложность**: СРЕДНЯЯ

### 8. ❌ Incremental Compilation
**Важность**: ВЫСОКАЯ (для скорости разработки)
**Сложность**: ВЫСОКАЯ

### 9. ❌ Better Error Messages
**Текущее**:
```
Parse error: Unexpected token in pattern: STRING_LITERAL(GET)
```

**Нужно** (как в Rust):
```
error[E0308]: mismatched types
  --> test.aur:12:5
   |
12 |     | "GET" => GET
   |       ^^^^^ pattern requires a constructor, found string literal
   |
   = help: try using a constructor pattern like `Method(name)` or add string matching support
   = note: string patterns are not yet supported in Aurora match expressions
```

**Важность**: ОЧЕНЬ ВЫСОКАЯ (UX)
**Сложность**: СРЕДНЯЯ

### 10. ❌ String Patterns in Match
```aurora
// СЕЙЧАС НЕ РАБОТАЕТ:
match method
  | "GET" => ...   // ❌ Parse error
  | "POST" => ...
```

**Важность**: СРЕДНЯЯ
**Сложность**: НИЗКАЯ (просто добавить в parser)

---

## План улучшений

### Фаза 1: Критические баги (1-2 дня)
1. ✅ **FIX**: Обрывание тела функции с множественными statements
2. ✅ **FIX**: Generic variant type generation (Result<T, E>)
3. ✅ **FIX**: constexpr на IO функциях
4. ✅ **TEST**: Запустить test_real_world.aur успешно

### Фаза 2: Рефакторинг архитектуры (1-2 недели)
1. ✅ **REFACTOR**: Создать сервисы (TypeInferrer, TypeChecker, ExpressionBuilder)
2. ✅ **REFACTOR**: Убрать transformer.send из всех правил
3. ✅ **REFACTOR**: Упростить IIFE generation (только когда действительно нужны)
4. ✅ **ADD**: Visitor pattern для AST traversal
5. ✅ **ADD**: Builder pattern для CoreIR construction

### Фаза 3: Улучшение языка (2-4 недели)
1. ✅ **FEATURE**: Mutable variables (let mut)
2. ✅ **FEATURE**: String patterns in match
3. ✅ **FEATURE**: Better error messages с source locations
4. ✅ **FEATURE**: Основы Traits system

### Фаза 4: Инструментарий (4-8 недель)
1. ✅ **TOOL**: LSP server (автодополнение, goto definition)
2. ✅ **TOOL**: REPL
3. ✅ **TOOL**: Package manager
4. ✅ **TOOL**: Debugger integration

---

## Стиль кода - что улучшить

### 1. Использовать Value Objects
```ruby
# До
def infer_type(name)
  {name: "i32", kind: :primitive}
end

# После
Type = Data.define(:name, :kind, :params)
def infer_type(name)
  Type.new(name: "i32", kind: :primitive, params: [])
end
```

### 2. Railway-Oriented Programming для ошибок
```ruby
# До
def transform(node)
  raise "Invalid node" unless valid?(node)
  result = process(node)
  raise "Failed" if result.nil?
  result
end

# После
def transform(node)
  Result.new
    .and_then { validate(node) }
    .and_then { process(node) }
    .and_then { finalize }
end
```

### 3. Immutable Data Structures
```ruby
# До
@var_types[name] = type  # Mutation!

# После
context.with_type(name, type) do
  # работа в новом context
end
```

### 4. Functional Core, Imperative Shell
```ruby
# Core (pure functions)
module TypeInference
  def self.infer(expr, context)
    # pure, no side effects
  end
end

# Shell (coordinator)
class ToCore
  def transform(ast)
    # orchestrates pure functions
    TypeInference.infer(expr, context)
  end
end
```

---

## Выводы

### Что работает хорошо ✅
- Rules-based architecture (LLVM-style)
- EventBus для диагностики
- PassManager concept
- Генерация C++ из CoreIR
- Test coverage (401 тестов)

### Что нужно исправить срочно 🔴
1. Обрывание тела функции
2. Generic variant type generation
3. Убрать transformer.send из правил

### Что улучшит архитектуру 🟡
1. Services вместо Transformers
2. Visitor pattern
3. Builder pattern
4. Immutable context

### Что сделает язык полноценным 🚀
1. Mutable variables
2. Traits system
3. Better errors
4. LSP server

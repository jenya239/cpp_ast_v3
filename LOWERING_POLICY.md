# Lowering Policy - Критерии выбора стратегий кодогенерации

**Дата:** 2025-10-29
**Статус:** Архитектурный документ

## Введение

Этот документ определяет **детерминированные правила** выбора между различными стратегиями lowering Aurora → C++:
- **Runtime helpers** - функции из библиотеки `aurora::*`
- **IIFE (Immediately Invoked Function Expression)** - `[&]() { ... }()`
- **Inline codegen** - прямая генерация C++ конструкций
- **Scope + tmp variable** - блок с временной переменной

## Принципы проектирования

### 1. Баланс между читаемостью и производительностью
- Простой код → читаемый C++
- Сложный код → runtime helpers или IIFE

### 2. Минимизация загрязнения scope
- Используем блоки `{ }` для локализации временных переменных
- IIFE только когда нужен сложный control flow

### 3. Переиспользование через runtime
- Повторяющаяся логика → runtime функция
- Уникальная логика → inline

### 4. Zero-cost abstractions
- Compiler-friendly паттерны (inline, templates)
- Избегаем лишних аллокаций

---

## 1. Runtime Helpers

**Когда использовать runtime библиотеку:**

| Категория | Примеры | Критерий |
|-----------|---------|----------|
| **Collections** | `map`, `filter`, `fold`, `reverse`, `join` | Всегда через runtime |
| **IO** | `println`, `read_line`, `args` | Всегда через runtime |
| **String ops** | `to_string`, `format`, `split`, `trim` | Всегда через runtime |
| **Regex** | `regex`, `regex_i`, `match`, `test` | Всегда через runtime |
| **ADT helpers** | `overloaded<Ts...>` для std::visit | Всегда через runtime |
| **Math** | `abs`, `min`, `max`, `sqrt` | Через runtime или std:: |
| **Error handling** | `Expected<T,E>`, `Result<T>` | Когда добавим - через runtime |

**Обоснование:**
- ✅ **Переиспользование** - одна реализация для всех генераций
- ✅ **Тестируемость** - можно unit-тестировать runtime отдельно
- ✅ **Оптимизация** - компилятор inline'ит template функции
- ✅ **Стабильность** - изменения в runtime не требуют перекомпиляции всего
- ✅ **Расширяемость** - легко добавлять новые функции

**Примеры:**

```cpp
// ✅ GOOD: через runtime
auto result = aurora::collections::map(items, [&](auto x) { return x * 2; });
aurora::io::println("Hello", name);
auto regex = aurora::regex_i("pattern");

// ❌ BAD: inline generation
auto result = [&]() {
  std::vector<int> _tmp;
  for (auto x : items) _tmp.push_back(x * 2);
  return _tmp;
}();
```

---

## 2. IIFE (Lambda IIFE)

**Когда использовать IIFE:**

### 2.1 Match с regex patterns
```aurora
match text {
  /^user:(\w+)$/ => handle_user(user)
  /^id:(\d+)$/ => handle_id(id)
  _ => default()
}
```
**Генерация:**
```cpp
[&]() {
  if (auto m = aurora::regex("^user:(\\w+)$").match(text)) {
    auto user = m.get(1).text();
    return handle_user(user);
  }
  if (auto m = aurora::regex("^id:(\\d+)$").match(text)) {
    auto id = m.get(1).text();
    return handle_id(id);
  }
  return default();
}()
```
**Обоснование:** Нужны ранние `return`, захват match результатов

### 2.2 List comprehension
```aurora
[x * 2 for x in items if x > 0]
```
**Генерация:**
```cpp
[&]() {
  std::vector<int> result;
  for (auto x : items) {
    if (x > 0) result.push_back(x * 2);
  }
  return result;
}()
```
**Обоснование:** Expression-semantics, локальный `result`

### 2.3 Сложные block expressions (≥5 statements с control flow)
```aurora
{
  let x = compute_heavy()
  if x > threshold {
    let y = process(x)
    match y {
      Ok(v) => v * 2
      Err(e) => fallback(e)
    }
  } else {
    default
  }
}
```
**Генерация:** IIFE
```cpp
[&]() {
  auto x = compute_heavy();
  if (x > threshold) {
    auto y = process(x);
    return std::visit(overloaded{
      [&](const Ok& ok) { return ok.value * 2; },
      [&](const Err& err) { return fallback(err.value); }
    }, y);
  }
  return default;
}()
```
**Обоснование:** Сложный control flow, изоляция scope

---

## 3. Inline Codegen

**Когда использовать прямую генерацию C++:**

### 3.1 Simple expressions
```aurora
x + y * 2
not (a and b)
arr[index]
obj.field
```
**Генерация:** Прямой C++
```cpp
x + y * 2
!(a && b)
arr[index]
obj.field
```

### 3.2 Simple if (ternary)
```aurora
if condition { a } else { b }
```
**Генерация:**
```cpp
condition ? a : b
```
**Критерий:** Простые expression branches, нет statements

### 3.3 Match с чистым ADT (≤5 веток)
```aurora
match option {
  Some(x) => x + 1
  None => 0
}
```
**Генерация:**
```cpp
std::visit(overloaded{
  [&](const Some& some) { return some.value + 1; },
  [&](const None&) { return 0; }
}, option)
```

### 3.4 For/While loops (statement context)
```aurora
for i in 0..10 {
  println(i)
}
```
**Генерация:**
```cpp
for (int i = 0; i < 10; ++i) {
  aurora::io::println(i);
}
```

---

## 4. Scope + Tmp Variable

**Когда использовать блок с временной переменной:**

### 4.1 Simple block expressions (≤3 statements, нет control flow)
```aurora
{
  let x = compute()
  let y = x * 2
  y + 1
}
```
**Генерация:**
```cpp
({
  auto x = compute();
  auto y = x * 2;
  y + 1;
})
```
**Или с GCC statement expression:**
```cpp
({ auto x = compute(); auto y = x * 2; y + 1; })
```

### 4.2 If statement returning value (когда нужен tmp)
```aurora
let result = if condition {
  expensive_computation()
} else {
  fallback()
}
```
**Генерация (если типы разные):**
```cpp
std::variant<T1, T2> _tmp;
if (condition) {
  _tmp = expensive_computation();
} else {
  _tmp = fallback();
}
auto result = _tmp;
```

**Генерация (если типы одинаковые):**
```cpp
T _tmp;
if (condition) {
  _tmp = expensive_computation();
} else {
  _tmp = fallback();
}
auto result = _tmp;
```

---

## Таблица решений (Decision Matrix)

| Конструкция | Условие | Стратегия | Пример |
|-------------|---------|-----------|--------|
| **Collections ops** | `map`, `filter`, `fold` | Runtime | `aurora::collections::map` |
| **IO** | `println`, `read_line` | Runtime | `aurora::io::println` |
| **Regex** | Любое использование | Runtime | `aurora::regex("pat")` |
| **Match** | Regex patterns | IIFE | `[&]() { if (m) return ...; }()` |
| **Match** | Pure ADT, ≤5 веток | Inline | `std::visit(overloaded{...})` |
| **Match** | Pure ADT, >5 веток | Named visitor (future) | `class Visitor { ... }` |
| **List comp** | Всегда | IIFE | `[&]() { vec result; ...; return result; }()` |
| **Block** | ≤3 stmts, no ctrl flow | Scope/GCC expr | `({ auto x = ...; x+1; })` |
| **Block** | >3 stmts или ctrl flow | IIFE | `[&]() { ...; return val; }()` |
| **If** | Expression, простые ветки | Ternary | `cond ? a : b` |
| **If** | Statement context | Native if | `if (c) { } else { }` |
| **If** | Different types | variant + tmp | `variant<A,B> _tmp; if...` |
| **Loop** | Statement context | Native for/while | `for (auto x : xs) { }` |
| **Simple expr** | Arithmetic, logic, access | Inline | `x + y`, `arr[i]`, `obj.f` |

---

## Эвристики для Block Expressions

Текущая реализация `lower_block_expr` всегда использует IIFE. Предлагается следующий анализ:

### Простой блок (→ Scope + tmp):
```ruby
def should_use_scope_tmp?(block_expr)
  # Эвристика:
  # 1. ≤3 statements
  # 2. Нет вложенных if/match/loop
  # 3. Все statements - это let или простые expr
  block_expr.statements.size <= 3 &&
    block_expr.statements.all? { |stmt| simple_statement?(stmt) } &&
    !has_control_flow?(block_expr.result)
end

def simple_statement?(stmt)
  stmt.is_a?(CoreIR::LetStmt) ||
    stmt.is_a?(CoreIR::ExprStmt)
end

def has_control_flow?(expr)
  return false unless expr
  expr.is_a?(CoreIR::IfExpr) ||
    expr.is_a?(CoreIR::MatchExpr) ||
    expr.is_a?(CoreIR::BlockExpr)
end
```

### Сложный блок (→ IIFE):
- Более 3 statements
- Есть if/match/loop внутри
- Нужны ранние return

---

## Будущие расширения

### 1. Named Visitors для больших match
Когда веток >5-7, генерировать class:
```cpp
class MatchVisitor {
  template<typename T>
  Result operator()(const T& val) { ... }
};
auto result = std::visit(MatchVisitor{}, scrutinee);
```

### 2. Loop helpers для циклов с результатом
```cpp
template<typename T, typename StepFn>
T aurora::loop(T init, StepFn&& step) {
  T state = init;
  while (auto opt = step(state)) {
    if (!opt->cont) break;
    state = opt->value;
  }
  return state;
}
```

### 3. Expected<T,E> для error handling
```cpp
auto result = compute()
  .and_then([](auto x) { return validate(x); })
  .map([](auto x) { return x * 2; })
  .unwrap_or(default_value);
```

### 4. Macro для GCC statement expressions (опционально)
```cpp
#ifdef __GNUC__
  #define EXPR_BLOCK(...) ({ __VA_ARGS__ })
#else
  #define EXPR_BLOCK(...) [&]() { __VA_ARGS__ }()
#endif
```

---

## Конфигурация (RuntimePolicy)

Возможность настроить стратегии через конфиг:

```ruby
class RuntimePolicy
  attr_accessor :block_stmt_strategy      # :scope_tmp | :iife
  attr_accessor :block_expr_simple        # :scope_tmp | :gcc_expr | :iife
  attr_accessor :block_expr_complex       # :iife | :scope_tmp
  attr_accessor :if_join_strategy         # :ternary | :variant | :tmp
  attr_accessor :match_threshold          # integer (num branches for named visitor)
  attr_accessor :loop_capture_strategy    # :lambda | :fn_ptr (when possible)
  attr_accessor :use_gcc_extensions       # bool (enable ({ }) expressions)
  attr_accessor :error_model              # :expected | :exceptions

  def initialize
    @block_stmt_strategy = :scope_tmp
    @block_expr_simple = :gcc_expr  # если GCC, иначе :iife
    @block_expr_complex = :iife
    @if_join_strategy = :ternary    # или :variant если типы разные
    @match_threshold = 5
    @loop_capture_strategy = :lambda
    @use_gcc_extensions = false
    @error_model = :expected
  end
end
```

---

## Примеры комбинаций

### Пример 1: Simple computation
```aurora
let result = {
  let x = compute()
  x * 2 + 1
}
```
**Стратегия:** Scope + tmp (≤3 stmts, no control flow)
```cpp
auto result = ({
  auto x = compute();
  x * 2 + 1;
});
```

### Пример 2: Collection processing
```aurora
let doubled = items.map(|x| x * 2).filter(|x| x > 10)
```
**Стратегия:** Runtime
```cpp
auto doubled = aurora::collections::filter(
  aurora::collections::map(items, [&](auto x) { return x * 2; }),
  [&](auto x) { return x > 10; }
);
```

### Пример 3: Pattern matching with regex
```aurora
let extracted = match input {
  /^(\d+)$/ => parse_int(d)
  /^(\w+)$/ => lookup(w)
  _ => default()
}
```
**Стратегия:** IIFE (regex patterns, early returns)
```cpp
auto extracted = [&]() {
  if (auto m = aurora::regex("^(\\d+)$").match(input)) {
    auto d = m.get(1).text();
    return parse_int(d);
  }
  if (auto m = aurora::regex("^(\\w+)$").match(input)) {
    auto w = m.get(1).text();
    return lookup(w);
  }
  return default();
}();
```

### Пример 4: Complex block
```aurora
let result = {
  let x = fetch_data()
  if x.is_valid() {
    let processed = process(x)
    match processed {
      Ok(v) => v
      Err(e) => handle_error(e)
    }
  } else {
    fallback()
  }
}
```
**Стратегия:** IIFE (сложный control flow)
```cpp
auto result = [&]() {
  auto x = fetch_data();
  if (x.is_valid()) {
    auto processed = process(x);
    return std::visit(overloaded{
      [&](const Ok& ok) { return ok.value; },
      [&](const Err& err) { return handle_error(err.value); }
    }, processed);
  }
  return fallback();
}();
```

---

## Реализация

### Phase 1: Документация + эвристики (текущий этап)
- ✅ Определить критерии
- ⏳ Согласовать с пользователем
- ⏳ Создать `RuntimePolicy` класс

### Phase 2: Рефакторинг `lower_block_expr`
1. Добавить анализ сложности блока
2. Реализовать `should_use_scope_tmp?` и подобные
3. Генерировать scope+tmp для простых случаев
4. Сохранить IIFE для сложных

### Phase 3: Расширение runtime
1. Добавить missing helpers (`Expected<T,E>`, loop utilities)
2. Генерировать runtime через Ruby DSL (опционально)

### Phase 4: Тестирование
1. Unit-тесты для каждой стратегии
2. Бенчмарки производительности
3. Проверка читаемости сгенерированного C++

---

## Метрики качества

**Критерии успеха:**
- ✅ Сгенерированный C++ читаем и идиоматичен
- ✅ Нет лишних аллокаций/копирований
- ✅ Компилятор может inline/оптимизировать
- ✅ Сохранены все 1140 тестов
- ✅ Runtime минимален и переиспользуем

**Анти-паттерны:**
- ❌ IIFE везде (overuse lambdas)
- ❌ Генерация дубликатов вместо runtime
- ❌ Неоптимизируемый код
- ❌ Загрязнение scope временными переменными

---

## Вопросы для обсуждения

1. ✅ Когда использовать runtime vs IIFE vs inline?
2. ⏳ Нужны ли GCC statement expressions `({ })`?
3. ⏳ Приоритет Named Visitors для больших match?
4. ⏳ Добавить `Expected<T,E>` в runtime сейчас или позже?
5. ⏳ Ruby DSL для генерации runtime - нужен ли?

---

## Связанные документы

- `CURRENT_SESSION.md` - текущая сессия
- `CONTINUE_PROMPT.md` - статус рефакторинга
- `docs/runtime.chat.md` - детальное обсуждение runtime
- `docs/aurora_mutability_refactor.md` - план рефакторинга
- `ARCHITECTURE_GUIDE.md` - текущая архитектура

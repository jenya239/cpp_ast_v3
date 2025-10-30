# Aurora Rules-Based Refactoring Analysis

**Дата:** 2025-10-30
**Цель:** Завершить полный переход на rules-based архитектуру

## ✅ ПРОГРЕСС РЕФАКТОРИНГА

**Дата обновления:** 2025-10-30 (конец сессии)

### Завершено Phase 1 & Phase 2: C++ Expression и Statement Rules

**Реализовано:**
- ✅ Базовая инфраструктура: `CppExpressionRule` и `CppStatementRule`
- ✅ 15 C++ expression rules (покрывают 100% expression types)
- ✅ 10 C++ statement rules (покрывают 100% statement types)
- ✅ Интегрированы в `CppLowering` через `build_default_rule_engine`
- ✅ Все тесты проходят (1397 runs, 3617 assertions, 0 failures)

**Файлы созданы:**
```
lib/aurora/rules/cpp/
├── cpp_expression_rule.rb (базовый класс)
├── cpp_statement_rule.rb (базовый класс)
├── expression/
│   ├── literal_rule.rb
│   ├── var_ref_rule.rb
│   ├── binary_rule.rb
│   ├── unary_rule.rb
│   ├── call_rule.rb
│   ├── regex_rule.rb
│   ├── member_rule.rb
│   ├── index_rule.rb
│   ├── array_literal_rule.rb
│   ├── record_rule.rb
│   ├── if_rule.rb
│   ├── block_rule.rb
│   ├── lambda_rule.rb
│   ├── match_rule.rb
│   └── list_comp_rule.rb
└── statement/
    ├── expr_statement_rule.rb
    ├── variable_decl_rule.rb
    ├── assignment_rule.rb
    ├── return_rule.rb
    ├── break_rule.rb
    ├── continue_rule.rb
    ├── if_rule.rb
    ├── while_rule.rb
    ├── for_rule.rb
    └── match_rule.rb
```

**Файлы модифицированы:**
- `lib/aurora/backend/cpp_lowering.rb` - добавлены requires и регистрация всех rules
- `lib/aurora/backend/cpp_lowering/expression_lowerer.rb` - добавлен `apply_cpp_expression_rules`
- `lib/aurora/backend/cpp_lowering/statement_lowerer.rb` - добавлены:
  - `apply_cpp_statement_rules`
  - Extracted methods: `lower_expr_statement`, `lower_variable_decl_stmt`, `lower_assignment_stmt`, `lower_return_stmt`, `lower_break_stmt`, `lower_continue_stmt`

**Архитектурный паттерн:**
- DelegatingRule pattern (rules делегируют к методам в Lowerer)
- Try-rules-first подход: `apply_rules(node) → fallback to imperative`
- Context passing: lowerer, type_registry, function_registry, rule_engine, runtime_policy, event_bus

**Метрики:**
- **ToCore:** ~35 rules (фронтенд)
- **CppLowering:** 26 rules (бэкенд) ← **НОВОЕ**
- **Итого:** ~61 rules в Aurora

---

## Текущее состояние

### ✅ Что уже на rules (ToCore - фронтенд)

**Expression rules (19 типов):**
- Literals (Int, Float, String, Regex, Unit)
- VarRef, Binary, Unary
- Call, Member, Pipe
- Let, RecordLiteral, ArrayLiteral
- If, Match, Lambda
- Block, Do, IndexAccess
- ForLoop, WhileLoop, ListComprehension

**Statement rules (10 типов):**
- ExprStmt, VariableDecl, Assignment
- For, If, While
- Return, Break, Continue, Block

**Специальные rules:**
- `SumConstructorRule` - ADT конструкторы
- `MatchRule` - pattern matching анализ
- `FunctionEffectRule` - эффекты функций (constexpr, noexcept)
- `StdlibImportRule` - автоматический импорт stdlib

**Итого:** ~35+ rules для ToCore, ~2736 строк кода

---

## ❌ Что НЕ на rules (CppLowering - бэкенд)

### C++ Backend (0 rules, ~1647 строк)

**expression_lowerer.rb (33K, ~800 строк):**
```
lower_expression(expr) - большой case statement с ~25 ветками:
  ├── LiteralExpr
  ├── VarExpr
  ├── BinaryExpr
  ├── UnaryExpr
  ├── CallExpr
  ├── MemberExpr
  ├── RecordExpr
  ├── IfExpr
  ├── MatchExpr (сложный - std::visit генерация)
  ├── LambdaExpr
  ├── ArrayLiteralExpr
  ├── IndexExpr
  ├── ListCompExpr (IIFE генерация)
  ├── BlockExpr (runtime policy integration)
  └── ...
```

**statement_lowerer.rb (10K, ~250 строк):**
```
lower_coreir_statement(stmt) - case с ~10 ветками:
  ├── VariableDeclStmt
  ├── AssignmentStmt
  ├── ExprStmt
  ├── IfStmt
  ├── MatchStmt
  ├── ForStmt
  ├── WhileStmt
  ├── ReturnStmt
  ├── BreakStmt
  └── ContinueStmt
```

**type_lowerer.rb (4.8K, ~120 строк):**
```
map_type(type) - конвертация CoreIR types → C++ types:
  ├── Primitive types (i32 → int)
  ├── ArrayType → std::vector<T>
  ├── FunctionType → std::function<R(Args...)>
  ├── SumType → std::variant<Ts...>
  ├── RecordType → custom struct
  └── GenericType → template parameters
```

**function_lowerer.rb (3.9K, ~100 строк):**
```
lower_function(func):
  - Parameter lowering
  - Body lowering
  - Template generation (generics)
  - Effect modifiers (constexpr, noexcept)
```

---

## Проблемы текущей архитектуры

### 1. C++ генерация - монолитный императивный код

**Проблемы:**
- Большие case statements (~25+ веток)
- Хардкодированная логика генерации
- Сложно добавлять новые backends (WASM, LLVM IR)
- Сложно тестировать отдельные части
- Нет event bus интеграции для диагностики

**Пример - lower_match:**
```ruby
def lower_match(match_expr)
  # ~150 строк imperative кода
  # Генерация std::visit, overloaded, regex matching
  # Все в одном месте, сложно расширять
end
```

### 2. Runtime Policy интеграция - недостаточно гибкая

**Проблема:**
- RuntimePolicy применяется только в `lower_block_expr`
- Нет policy для других конструкций (if, match, loops)
- Нет диагностики какая стратегия выбрана

**Нужно:**
- Policy rules для всех конструкций
- Event bus события о выборе стратегии
- Метрики использования (для оптимизации)

### 3. Нет C++ builder rules

**Проблема:**
- Прямая генерация CppAst узлов
- Нет переиспользования паттернов
- Сложно менять форматирование

**Нужно:**
- C++ pattern rules (visitor pattern, RAII, etc)
- Template generation rules
- Formatting rules

---

## План рефакторинга

### Phase 1: C++ Expression Rules (Приоритет: ВЫСОКИЙ)

**Цель:** Перевести expression_lowerer на rules

**Задачи:**
1. Создать `lib/aurora/rules/cpp/expression/` директорию
2. Реализовать базовый `CppExpressionRule` класс
3. Создать rules для каждого expression типа:
   - `LiteralRule` - простая трансформация
   - `VarRefRule` - простая
   - `BinaryRule` - операторы с precedence
   - `UnaryRule` - prefix/postfix
   - `CallRule` - function calls, member calls
   - `MemberRule` - field access, method access
   - `IfRule` - ternary vs if statement
   - `MatchRule` - std::visit generation
   - `LambdaRule` - capture, parameters
   - `BlockRule` - integration с RuntimePolicy
   - `ListCompRule` - IIFE или range-based
4. Интегрировать в `CppLowering.lower_expression`
5. Тесты для каждого rule

**Ожидаемый результат:**
- ~15 новых C++ expression rules
- Уменьшение expression_lowerer.rb с 800 → 200 строк
- Event bus интеграция (выбор стратегии)

---

### Phase 2: C++ Statement Rules (Приоритет: ВЫСОКИЙ)

**Цель:** Перевести statement_lowerer на rules

**Задачи:**
1. Создать `lib/aurora/rules/cpp/statement/` директорию
2. Базовый `CppStatementRule`
3. Rules для statements:
   - `VariableDeclRule`
   - `AssignmentRule`
   - `ExprStmtRule`
   - `IfStmtRule`
   - `MatchStmtRule`
   - `ForStmtRule`
   - `WhileStmtRule`
   - `ReturnStmtRule`
   - `BreakRule`, `ContinueRule`
4. Интеграция в `CppLowering.lower_statement`

**Ожидаемый результат:**
- ~10 новых C++ statement rules
- statement_lowerer.rb: 250 → 50 строк

---

### Phase 3: Type Lowering Rules (Приоритет: СРЕДНИЙ)

**Цель:** Правила для type mapping

**Задачи:**
1. `lib/aurora/rules/cpp/type/` директорию
2. Rules:
   - `PrimitiveTypeRule` - i32 → int
   - `ArrayTypeRule` - T[] → std::vector<T>
   - `FunctionTypeRule` - (Args) -> R → std::function
   - `SumTypeRule` - ADT → std::variant
   - `RecordTypeRule` - Record → struct
   - `GenericTypeRule` - generics → templates

**Ожидаемый результат:**
- ~6 type rules
- type_lowerer.rb: 120 → 30 строк

---

### Phase 4: Pattern Generation Rules (Приоритет: СРЕДНИЙ)

**Цель:** Переиспользуемые C++ паттерны

**Задачи:**
1. `lib/aurora/rules/cpp/pattern/` директорию
2. Rules для идиом:
   - `VisitorPatternRule` - std::visit generation
   - `RAIIPatternRule` - RAII wrappers
   - `IteratorPatternRule` - range-based loops
   - `TemplatePatternRule` - template generation
   - `NamespaceRule` - namespace organization

**Ожидаемый результат:**
- ~5 pattern rules
- Уменьшение дублирования кода

---

### Phase 5: RuntimePolicy Rules (Приоритет: ВЫСОКИЙ)

**Цель:** Policy-driven code generation

**Задачи:**
1. `BlockExprPolicyRule` - scope_tmp/iife/gcc_expr выбор
2. `IfExprPolicyRule` - ternary vs inline_if
3. `MatchPolicyRule` - visitor vs switch
4. `LoopPolicyRule` - range-based vs index
5. Event bus интеграция для диагностики

**Ожидаемый результат:**
- ~4 policy rules
- Метрики использования разных стратегий
- Улучшенная диагностика

---

### Phase 6: Event Bus & Diagnostics (Приоритет: ВЫСОКИЙ)

**Цель:** Расширенная диагностика и instrumentation

**Задачи:**
1. События для каждого rule:
   - `:cpp_expression_lowered`
   - `:cpp_statement_lowered`
   - `:cpp_type_mapped`
   - `:cpp_strategy_selected`
2. Diagnostic subscribers:
   - Performance metrics (время генерации)
   - Strategy usage stats
   - Code size metrics
3. Debug mode с подробными логами

**Ожидаемый результат:**
- Полная observability пайплайна
- Данные для оптимизации

---

### Phase 7: Remove Fallback Code (Приоритет: НИЗКИЙ)

**Цель:** Убрать старые case statements

**Задачи:**
1. Проверить что все ветки покрыты rules
2. Заменить case statements на:
   ```ruby
   def lower_expression(expr)
     result = @rule_engine.apply(:cpp_expression, expr, context: ...)
     raise "No rule for #{expr.class}" if result.equal?(expr)
     result
   end
   ```
3. Удалить старые методы

**Ожидаемый результат:**
- Полностью rule-driven архитектура
- Уменьшение кода на ~50%

---

## Метрики успеха

### Текущие (до рефакторинга):
- **ToCore:** 2736 строк, ~35 rules ✅
- **CppLowering:** 1647 строк, 0 rules ❌
- **Test coverage:** ~1397 тестов
- **Rules total:** 35

### Целевые (после рефакторинга):
- **ToCore:** 2736 строк, 35 rules ✅
- **CppLowering:** 400 строк, 40+ rules ✅
- **Test coverage:** +100 rule tests
- **Rules total:** 75+
- **Event bus:** полная интеграция
- **Diagnostics:** метрики и логирование

---

## Риски и митигации

### Риск 1: Регрессии в тестах
**Митигация:**
- Incremental refactoring (по одному rule за раз)
- Сохранять fallback code до полной проверки
- Запускать весь test suite после каждого изменения

### Риск 2: Overhead rules
**Митигация:**
- Benchmark'ить performance
- Оптимизировать rule dispatch
- Кэшировать rule lookup

### Риск 3: Усложнение архитектуры
**Митигация:**
- Хорошая документация каждого rule
- Примеры использования
- Debug tools для rule tracing

---

## Следующие шаги

1. **Начать с Phase 1** - C++ Expression Rules
2. **Создать базовые классы** - `CppExpressionRule`, `CppStatementRule`
3. **Реализовать 3-5 простых rules** - Literal, VarRef, Binary
4. **Написать тесты**
5. **Интегрировать в CppLowering**
6. **Запустить test suite**
7. **Продолжить с остальными rules**

**Приоритет:** Phase 1 (Expression) → Phase 2 (Statement) → Phase 5 (Policy) → Phase 6 (EventBus)

---

## Вопросы для обсуждения

1. Начать с самых простых rules (Literal, VarRef) или сложных (Match, ListComp)?
2. Оставлять fallback code или удалять сразу после добавления rule?
3. Нужен ли отдельный RuleRegistry для C++ rules?
4. Как организовать testing infrastructure для rules?

# C++ Backend Rules Refactoring - TODO

**Дата начала:** 2025-10-30
**Цель:** Переписать все C++ backend rules с полной логикой внутри (без делегации)

## Принципы правильной архитектуры

1. ✅ ВСЯ логика в самом rule (автономное тестирование)
2. ✅ Нет `return unless applies?` (движок сам проверяет)
3. ✅ State через context, не через instance variables
4. ✅ Helpers только для pure functions (без state)
5. ✅ Нет скрытых зависимостей

## Прогресс

### 1. Helpers Module (1/1) - ✅ COMPLETED

- [x] Создать `lib/aurora/backend/cpp_lowering/helpers.rb`
  - [x] `build_aurora_string(value)` - pure function
  - [x] `sanitize_identifier(name)` - pure function
  - [x] `qualified_function_name(name, function_registry)` - чистая функция
  - [x] `map_type(type, type_map:, type_registry:)` - type mapping
  - [x] `escape_cpp_string`, `cpp_string_literal`, `type_requires_auto?`
  - [x] `build_template_signature`, `build_requires_clause`
  - [x] `should_lower_as_statement?`, `cpp_keyword?`

### 2. Expression Rules (12/15) - IN PROGRESS

#### ✅ Completed (12)
- [x] LiteralRule - ПОЛНОСТЬЮ ПЕРЕПИСАН (использует Helpers, нет делегации)
- [x] VarRefRule - ПОЛНОСТЬЮ ПЕРЕПИСАН (использует Helpers, нет делегации)
- [x] RegexRule - ПОЛНОСТЬЮ ПЕРЕПИСАН (использует Helpers, нет делегации)
- [x] MemberRule - ПОЛНОСТЬЮ ПЕРЕПИСАН (использует Helpers для sanitize_identifier)
- [x] IndexRule - ПОЛНОСТЬЮ ПЕРЕПИСАН (содержит логику, рекурсия через lowerer)
- [x] ArrayLiteralRule - ПОЛНОСТЬЮ ПЕРЕПИСАН (использует Helpers.map_type, рекурсия через lowerer)
- [x] BinaryRule - обновлен (убран `return unless applies?`, рекурсия через lowerer)
- [x] UnaryRule - обновлен (убран `return unless applies?`, рекурсия через lowerer)
- [x] RecordRule - ПОЛНОСТЬЮ ПЕРЕПИСАН (использует Helpers.map_type, рекурсия через lowerer)
- [x] IfRule - ПОЛНОСТЬЮ ПЕРЕПИСАН (использует Helpers.should_lower_as_statement?, рекурсия через lowerer)
- [x] LambdaRule - ПОЛНОСТЬЮ ПЕРЕПИСАН (использует Helpers, обрабатывает captures, params, body)
- [x] BlockRule - ПОЛНОСТЬЮ ПЕРЕПИСАН (RuntimePolicy интеграция, 4 стратегии: IIFE/GCC/scope_tmp/inline)

#### 🔄 Need Rewrite (3)
- [ ] MatchRule - убрать делегацию (сложная - std::visit)
- [ ] ListCompRule - убрать делегацию (IIFE generation)
- [ ] CallRule - убрать делегацию (очень сложная ~200 строк)

### 3. Statement Rules (0/10) - NOT STARTED

- [ ] ExprStatementRule
- [ ] VariableDeclRule
- [ ] AssignmentRule
- [ ] ReturnRule
- [ ] BreakRule
- [ ] ContinueRule
- [ ] IfRule
- [ ] WhileRule
- [ ] ForRule
- [ ] MatchRule

### 4. Cleanup (0/4) - NOT STARTED

- [ ] Удалить `CppExpressionRule` (DelegatingRule базовый класс)
- [ ] Удалить `CppStatementRule` (DelegatingRule базовый класс)
- [ ] Удалить старые `lower_*` методы из expression_lowerer
- [ ] Удалить старые `lower_*` методы из statement_lowerer
- [ ] Удалить case statements и fallback код

### 5. Tests (0/2) - NOT STARTED

- [ ] Запустить полный test suite
- [ ] Убедиться что 0 failures

## Текущая задача

**СЕЙЧАС:** Переписывание оставшихся expression rules (3/15 осталось)

**ПРОГРЕСС:** 12/15 completed (80%)

**СЛЕДУЮЩЕЕ:** Сложные rules - MatchRule (~200 строк, std::visit), ListCompRule (IIFE), CallRule (~200 строк)

## Notes

### Context передача
Rules получают context с:
- `lowerer` - для рекурсивных вызовов `lower_expression`
- `type_map` - для map_type helper
- `type_registry` - для TypeRegistry lookups
- `function_registry` - для qualified function names
- `runtime_policy` - для стратегий lowering
- `event_bus` - для событий

### Рекурсивные вызовы
Некоторые rules должны вызывать `lower_expression` рекурсивно (Binary, Unary, etc).
**Решение:** Передавать `lowerer` в context и вызывать `lowerer.send(:lower_expression, node)`

### RuntimePolicy integration
BlockRule, IfRule используют RuntimePolicy для стратегий lowering.
**Решение:** Передавать `runtime_policy` в context

### Сложные rules
CallRule, MatchRule очень сложные (~200 строк логики).
**Подход:** Разбить на приватные методы внутри rule класса

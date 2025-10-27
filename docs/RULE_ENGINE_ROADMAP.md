# Rule Engine Roadmap

## Сложные подсистемы

### 1. `match`
- ✅ `MatchRule` подключён к стадии `:core_ir_match_expr` и orchestrat'ит вызовы `MatchAnalyzer`, чтобы собирать ветви `match` уже в rule-слое.
- Следующий шаг — расширить правило проверками исчерпываемости и отчётами о незадействованных паттернах (eventually через event bus) и вынести регистрацию биндингов в отдельные под-правила.

### 2. Унификация типов
- `TypeConstraintSolver` + `GenericCallResolver`.
- Запланировать rule для кастомных constraints (`Numeric`, пользовательские).

### 3. Эффекты (`constexpr`, `noexcept`)
- ✅ `EffectAnalyzer` вынесен в сервис `Aurora::TypeSystem::EffectAnalyzer`, а стадия `:core_ir_function` пополнилась `FunctionEffectRule`, чтобы маркировать функции эффектами централизованно.
- Следующий шаг — расширить анализ до побочных эффектов (`io`, `panic`) и интегрировать с будущим event bus.

### 4. Stdlib
- ✅ `StdlibSignatureRegistry` поставляет метаданные (с AST) из `StdlibScanner`.
- ✅ `StdlibImportRule` подключает функции/типы через rule-engine (`:core_ir_stdlib_import`).
- Следующий шаг — расширить правила для дополнительных кейсов (selective type-only import, валидация, instrumentation).

## Декомпозиция миграции
1. `ToCore`: покрыть `transform_expression`/`transform_block_expr` правилами, начиная с `match`.
2. Поведение sugar (`pipe`, comprehension) -> правила.
3. C++ генератор -> builder + правила (`target/cpp_*`): стартовали с `:cpp_function_declaration` (эффекты/модификаторы), далее — классы и типы.
4. DI Application: сборка всех сервисов/правил.
5. Event bus, строгий режим.

## Приоритет на ближайшее время
1. Усилить `MatchRule`: проверки исчерпываемости, предупреждения про мёртвые ветви, публикация событий.
2. `ConstraintRules` (дополнения `TypeConstraintSolver`).
3. Развивать EventBus (подписчики для effect/type правил, расширенная диагностика).
4. Расширить stdlib-правила (валидации, события) поверх существующего реестра.
5. C++ rule пакеты.

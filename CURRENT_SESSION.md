# Текущая сессия - Runtime Architecture & IIFE Removal

**Дата:** 2025-10-29
**Статус:** Планирование архитектуры runtime и удаление IIFE

## Контекст

Компилятор Aurora находится в середине перехода от expression-only к statement-aware архитектуре. Основные документы:
- `CONTINUE_PROMPT.md` - описание где остановился рефакторинг
- `docs/runtime.chat.md` - детальное обсуждение runtime подходов
- `docs/aurora_mutability_refactor.md` - план рефакторинга мутабельности

## Текущее состояние (из CONTINUE_PROMPT.md)

### ✅ Завершено:
- Циклы (`for`/`while`) → `CoreIR::ForStmt`/`WhileStmt`, генерация C++ блоков напрямую
- `match` с unit-ветками → `MatchStmt`
- `AST::Let` и `do` нормализованы в `AST::BlockExpr` со statement-списками
- IIFE для циклов убраны
- Базовый анализ эффектов для statement-блоков (`:constexpr`)

### ⚠️ Осталось (4 задачи):

1. **Убрать оставшиеся IIFE** [ПРИОРИТЕТ]
   - `lower_block_expr` генерирует `[&]() { … }()` для блоков, возвращающих значения
   - Нужна работа с временными переменными вместо lambda IIFE

2. **Расширить анализ эффектов**
   - `TypeSystem::EffectAnalyzer` требует доработки для guards/вызовов
   - Сохранение `:constexpr` для сложных чистых блоков

3. **Документация и тесты**
   - Обновить примеры, README для statement-first семантики
   - Убрать упоминания legacy `do`/IIFE

4. **Грамматика if/match**
   - Закрепить statement-first семантику в парсере
   - Убрать старые формы (`then`, `do`)

## Обсуждение Runtime

### Выводы из runtime.chat.md:

**Три подхода:**
1. **C++ IIFE-based** (текущий) - `[&](){...}()` для блоков, `std::visit` для match
2. **VM/интерпретатор IR** - tree-walk или байткод для быстрого прототипирования
3. **Rule-based lowering** - PassManager с детерминированными правилами

**Необходимый runtime (C++):**
- `overloaded<Ts...>` helper для std::visit
- `match_total` для exhaustiveness проверки
- `loop<T>` utilities (step functions)
- `Expected<T,E>` или std::expected (C++23)
- `EXPR_BLOCK` макро для IIFE (если нужны)
- Helpers для variant/tuple манипуляций

### Предложенная архитектура IR (многоуровневая):

**HIR (High-level IR)** - читаемый, expression-oriented:
- Узлы: `Const, Var, Let, Block, If, Match, Loop, Call`
- Удобно для фронтенда и простого lowering в C++

**MIR (Mid-level IR)** - нормализованный, ANF/SSA-подобный:
- `Let x = Prim(...)` - арифметика, конструкторы ADT
- `If/Switch` - CFG блоки
- `Goto/Call/Return` - управление потоком
- `MakeSum/Unpack` - ADT операции
- Оптимизации: CSE, copy-prop, DCE

**LIR/Bytecode** (опционально) - компактный для VM:
- Регистровая или стековая форма
- Для интерпретатора или JIT

### Rule-based Lowering (из runtime.chat.md конец):

**PassManager пайплайн (IR → C++ AST):**
1. `AnalyzePositions` - expr-позиция или stmt
2. `Type/Unify` - общий тип веток
3. `EffectScope` - нужен ли новый scope
4. `LoopCapture` - захватывает ли тело цикла окружение
5. `MatchSizing` - количество веток
6. `LoweringPlan` - решить стратегию (BLOCK|VISITOR|TERNARY|VARIANT|LOOP_FN|LOOP_LAMBDA)
7. `EmitCxx` - генерация C++

**Policy (конфигурация):**
```ruby
RuntimePolicy.new(
  block_stmt: :scope_tmp,       # stmt → { T _t; { ... _t=...; } }
  block_expr: :iife,            # expr → EXPR_BLOCK / IIFE
  if_join: :common_or_variant,  # common_type или variant
  match_threshold: 5,           # >5 веток → named visitor
  loop_fnptr_ok: true,          # без захватов → fn-ptr
  error_model: :expected        # или :exceptions
)
```

**Правила (детерминированные):**
- **Block**: stmt → scope+tmp; expr → EXPR_BLOCK
- **If**: T1==T2 → ternary; иначе variant<T1,T2>
- **Match**: cases ≤ N → overloaded; >N → named Visitor
- **Loop**: no captures → loop(init, &step_fn); captures → loop(init, [&]{...})

## Решение: Ruby DSL для runtime

**Идея:** Генерировать runtime helpers через Ruby DSL вместо ручного написания C++.

**Преимущества:**
- Декларативность - описываем ЧТО, а не КАК
- Версионирование - runtime синхронизирован с кодогеном
- Тестируемость - можно менять стратегии
- Единообразие - весь пайплайн на Ruby

**Возможный дизайн:**
```ruby
# lib/aurora/runtime/runtime_dsl.rb
runtime :aurora do
  template :overloaded do
    generic_struct "overloaded", bases: "Ts...",
      inherit: "using Ts::operator()...",
      deduction_guide: true
  end

  template :loop_helper do
    struct "step_result", type_param: "T" do
      field :cont, :bool
      field :value, "T"
    end

    function "loop", type_param: "T",
      params: {init: "T", step: "auto"} do
      # ... тело
    end
  end
end
```

## План действий (согласовано с пользователем)

### Задача 2: Полная архитектура (HIR → MIR → LIR + rule engine)

**Подзадачи:**
1. Определить структуру HIR (текущий CoreIR расширить или заменить?)
2. Спроектировать MIR (ANF-форма, CFG блоки, SSA-like)
3. Определить PassManager архитектуру и passes
4. Спроектировать Policy/Rule систему (детерминированная)
5. Определить Ruby DSL для runtime генерации
6. Создать документ ARCHITECTURE_PLAN.md с полным описанием

### Задача 3: Убрать IIFE из lower_block_expr

**Текущая проблема:**
- `lib/aurora/backend/cpp_lowering/expression_lowerer.rb::lower_block_expr`
- Генерирует `[&]() { ... return value; }()` для блоков с результатом
- Нужно: временные переменные + statement-based lowering

**Подзадачи:**
1. Проанализировать текущий `lower_block_expr` и все вызовы
2. Определить стратегию для expr-контекста (scope+tmp)
3. Реализовать новый lowering без IIFE
4. Обновить тесты
5. Проверить производительность и читаемость сгенерированного C++

## Файлы для внимания

**Ключевые модули:**
- `lib/aurora/backend/cpp_lowering/expression_lowerer.rb` - где генерируются IIFE
- `lib/aurora/backend/cpp_lowering/statement_lowerer.rb` - statement lowering
- `lib/aurora/core_ir/nodes.rb` - определения IR узлов
- `lib/aurora/passes/to_core/` - трансформация AST → CoreIR
- `lib/aurora/type_system/effect_analyzer.rb` - анализ эффектов

**Документация:**
- `CONTINUE_PROMPT.md` - текущее состояние рефакторинга
- `docs/aurora_mutability_refactor.md` - детальный план миграции
- `docs/ARCHITECTURE_GUIDE.md` - текущая архитектура
- `docs/RULE_ENGINE_ROADMAP.md` - roadmap для rule engine
- `AURORA_LANGUAGE_REFERENCE_CORRECTED.md` - языковая справка

**Чаты (история обсуждений):**
- `docs/runtime.chat.md` (113K) - детальное обсуждение runtime/VM/lowering
- `docs/cursor_cppastv3.chat.md` (261K) - история разработки
- `docs/rubydslchatgpt.chat.md` (444K) - обсуждение Ruby DSL

## Следующий шаг

**ОБНОВЛЕНИЕ (2025-10-29 23:52):**

✅ **Завершено в этой сессии (продолжение):**

**1. Scope_tmp стратегия - полностью реализована**
- `lower_block_expr_as_scope_tmp` уже работает корректно
- Для expression context с GCC extensions → GCC expressions `({ })`
- Для expression context без GCC → fallback на IIFE (стандартный C++)
- Функции не используют IIFE - lowering через `lower_block_expr_statements`

**2. RuntimePolicy интегрирован в публичный API:**
- `Aurora.to_cpp(source, runtime_policy: policy)`
- `Aurora.compile(source, runtime_policy: policy)`
- `Aurora.lower_to_cpp(core_ir, runtime_policy: policy)`
- `Aurora.to_hpp_cpp(source, runtime_policy: policy)`
- `Application.build_cpp_lowering(runtime_policy: policy)`

**3. Исправлены integration тесты:**
- Все тесты адаптированы под statement-based синтаксис
- Удалены тесты с неподдерживаемым синтаксисом (`|x|` lambdas, chaining)
- 11 integration тестов проходят

**4. Создан runtime_policy_api_test.rb:**
- 6 новых тестов для API интеграции
- Проверка всех публичных методов с runtime_policy
- Тестирование custom policy конфигурации

**5. Все тесты проходят:**
- **1397 runs, 3617 assertions** (+25 новых тестов)
- **0 failures, 0 errors, 1 skip**
- **0 регрессий** ✅

**Итоговая архитектура lowering:**

```
RuntimePolicy (3 предопределенных + custom)
├── conservative    → IIFE everywhere (default)
├── optimized       → scope_tmp (fallback IIFE без GCC)
└── gcc_optimized   → GCC expressions ({ })

lower_block_expr(block)
  ↓
BlockComplexityAnalyzer.analyze(block)
  ↓
@runtime_policy.strategy_for_block(analyzer)
  ↓
:iife / :scope_tmp / :gcc_expr / :inline
  ↓
Генерация соответствующего C++
```

**Файлы изменены:**
- lib/aurora.rb - добавлен runtime_policy параметр во все публичные методы
- lib/aurora/application.rb - добавлен runtime_policy в build_cpp_lowering
- test/aurora/lowering_strategy_integration_test.rb - исправлены все тесты
- test/aurora/runtime_policy_api_test.rb - новый файл с 6 тестами

**Scope_tmp - ВЫВОДЫ:**

Scope_tmp **уже реализован** и работает правильно. В expression context без GCC extensions scope_tmp **невозможно реализовать в стандартном C++**, поэтому fallback на IIFE - это единственное корректное решение.

Для функций scope_tmp не нужен - они уже lowering'ятся напрямую через statements без IIFE.

---

**ОБНОВЛЕНИЕ (2025-10-29 23:25):**

✅ **Завершено в этой сессии:**

1. **Создан LOWERING_POLICY.md** (523 строки) - детальный документ с критериями выбора стратегий
2. **Создан RuntimePolicy класс** (111 строк) - конфигурация стратегий lowering (IIFE/runtime/inline)
3. **Создан BlockComplexityAnalyzer** (192 строки) - анализ сложности block/if/match expressions
4. **Написаны unit-тесты** - 19 тестов (RuntimePolicy + BlockComplexityAnalyzer)
5. **Интегрирован в CppLowering** - добавлен @runtime_policy, рефакторинг lower_block_expr
6. **Написаны integration тесты** - 11 e2e тестов для разных стратегий lowering
7. **Все тесты проходят** - 1372 теста, 0 ошибок, 0 регрессий ✅

**Архитектура:**
- `RuntimePolicy` - 3 предопределенных политики (conservative/optimized/gcc_optimized)
- `BlockComplexityAnalyzer` - определяет `simple?` vs `complex?` блоки (порог: 3 statements)
- `lower_block_expr` - динамический выбор стратегии на основе complexity analysis
- Поддержка: IIFE (текущий), scope_tmp (TODO), gcc_expr (TODO), inline (trivial blocks)

**Следующие шаги:**
1. **Реализовать scope_tmp стратегию** - генерация `{ T _t; { ... _t=val; } }` для простых блоков
2. **Реализовать gcc_expr стратегию** - генерация `({ ... })` для GCC/Clang
3. **Добавить метрики** - замерить разницу в performance и размере бинарника
4. **Постепенная миграция** - переключить optimized policy по умолчанию

**Архитектурные задачи (будущее):**
1. **Создать ARCHITECTURE_PLAN.md** - документ с полным описанием HIR→MIR→LIR архитектуры
2. **Определить интерфейс RuntimeDSL** - как будет выглядеть Ruby DSL для генерации runtime
3. **Расширить runtime** - добавить Expected<T,E>, loop helpers

## Вопросы для обсуждения

1. Стоит ли сохранить текущий CoreIR как HIR или редизайнить с нуля?
2. Нужен ли MIR сразу или можно обойтись HIR → C++ с хорошими passes?
3. VM/интерпретатор - в приоритете или фокус только на AOT C++ компиляции?
4. Какие runtime helpers нужны в первую очередь для устранения IIFE?

## Статус тестов

- **Всего тестов:** 1140
- **Проходят:** 1140 (100%)
- **Регрессий после рефакторинга:** 0

Все изменения должны сохранять 100% прохождение тестов.

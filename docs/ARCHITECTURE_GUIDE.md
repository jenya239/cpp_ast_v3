# MLC Compiler Architecture Guide

## Purpose

Документ фиксирует целевую архитектуру трансформаций MLC, чтобы разработчики и ИИ‑агенты могли безопасно расширять систему типов, добавлять эвристики и обслуживать стандартную библиотеку.

## Целевое состояние

Мы стремимся выстроить пайплайн по образцу зрелых компиляторов:

- **Формальная грамматика** — синтаксис языка описан в явном виде (LL/LR/PEG), парсер собирается генератором; текущий ручной парсер должен эволюционировать к спецификации, пригодной для автоматического тестирования и валидации.
- **Многоуровневые IR + pass manager** — фиксированные стадии (AST ➜ High IR ➜ Lowered IR ➜ Target) прогоняются через менеджер пассов; rule engine рассматривается как «pattern rewriter» внутри конкретных стадий, а не единственный механизм трансформаций.
- **Стандартные анализы** — разрешение имён, проверки типов, SSA/dataflow, эффектный анализ оформляются как изолированные пассы с чёткими контрактами.
- **Интеграция сервисов** (StdlibSignatureRegistry, Constraint Solver, Effect Analyzer, и т.д.) через configurable DI/Application слой и event bus, чтобы агенты могли подключать/отключать правила без модификации ядра.

Этот документ и дорожные карты должны отслеживать прогресс до момента, когда весь пайплайн соответствует этим принципам.

## Слоистая модель

1. **AST ➜ CoreIR** — чистая структурная трансформация. На этом уровне нет знания о целевом языке. Модули `BaseTransformer`, `ExpressionTransformer`, `StatementTransformer`, `FunctionTransformer` принимают AST и выдают CoreIR.
2. **CoreIR ➜ Lowered CoreIR** — слой семантических эвристик. Здесь живут `instantiate_signature`, проверки ограничений `validate_type_constraints`, будущий rule‑engine. Слой не зависит от генерации C++.
3. **Lowered CoreIR ➜ Target** — генерация (C++ AST DSL, CLI). Все решения по форматированию, ключевым словам и runtime живут только здесь.

## Сервисная архитектура (Phase 2 Complete ✅)

**Проблема:** Правила IRGen напрямую обращались к приватным методам трансформера через `transformer.send(:private_method)`, что нарушало инкапсуляцию и усложняло расширение компилятора.

**Решение:** Внедрена сервисно-ориентированная архитектура по образцу LLVM/MLIR. Все 82 вызова `transformer.send` из 20 правил устранены и заменены на обращения к специализированным сервисам.

### Сервисы (37 методов)

Сервисы находятся в `lib/aurora/services/` и предоставляют чистый API для правил:

1. **ExpressionTransformer** (8 методов) — рекурсивная трансформация выражений, statements, блоков
2. **TypeChecker** (13 методов) — проверка типов, совместимости, валидация
3. **PredicateService** (2 метода) — предикаты типов (void?, array?, record?)
4. **ContextManager** (5 методов) — управление scope (loop depth, lambda params, function return)
5. **TypeInferenceService** (5 методов) — вывод типов (переменные, вызовы, операции)
6. **RecordBuilderService** (4 метода) — построение record типов (анонимные/именованные)

### Пример использования

**До (anti-pattern):**
```ruby
def apply(node, context)
  transformer = context.fetch(:transformer)
  left = transformer.send(:transform_expression, node.left)
  type = transformer.send(:infer_binary_type, node.op, left.type, right.type)
  # ...
end
```

**После (clean separation):**
```ruby
def apply(node, context)
  expr_svc = context.fetch(:expression_transformer)
  type_inference = context.fetch(:type_inference)

  left = expr_svc.transform_expression(node.left)
  type = type_inference.infer_binary_type(node.op, left.type, right.type)
  # ...
end
```

### Архитектурные преимущества

- ✅ **Чёткое разделение ответственности**: правила → сервисы → трансформер
- ✅ **Нет нарушений инкапсуляции**: только публичный API через сервисы
- ✅ **Упрощённое тестирование**: сервисы можно мокировать независимо
- ✅ **Расширяемость**: новые правила добавляются без изменения трансформера
- ✅ **Следование LLVM/MLIR паттернам**: pattern rewriters + pass infrastructure

### Интеграция

Сервисы инициализируются в `MLC::IRGen` и передаются правилам через контекст:

```ruby
@expression_transformer_service = MLC::Services::ExpressionTransformer.new(self)
@type_checker_service = MLC::Services::TypeChecker.new(self)
# ... остальные сервисы

context = {
  transformer: self,
  expression_transformer: @expression_transformer_service,
  type_checker: @type_checker_service,
  type_inference: @type_inference_service,
  context_manager: @context_manager_service,
  record_builder: @record_builder_service,
  predicates: @predicate_service
}
```

## TypeContext

`TypeContext` управляет стековыми состояниями: параметрами типов, ожиданиями параметров лямбд, ожидаемыми типами возврата. Используйте хелперы `with_type_params`, `with_function_return`, `with_lambda_param_types` вместо прямой работы с массивами — это предотвращает утечки состояния и делает код безопасным для параллельных трансформаций.

```ruby
type_params = normalize_type_params(func.type_params)
with_type_params(type_params) do
  with_function_return(ret_type) do
    # ... трансформация тела функции ...
  end
end
```

## Generic Call Resolver

`TypeConstraintSolver` отвечает за унификацию и проверку ограничений типов. `GenericCallResolver` использует его для приведения параметров вызова к конкретным типам:

```ruby
inst = generic_call_resolver.instantiate(info, args, name: callee.name)
inst.param_types # конкретные типы аргументов
inst.ret_type    # конкретный тип возврата
```

В последующих шагах следует вынести эту логику в отдельный сервис `GenericCallResolver`, подключаемый через DI.

## Effect Analyzer

`EffectAnalyzer` оценивает CoreIR-тело функций и решает, какие эффекты (`:constexpr`, `:noexcept`) им назначить. Реальное применение эффектов происходит в правиле `Rules::IRGen::FunctionEffectRule` на стадии `:core_ir_function`, поэтому трансформер ограничивается подготовкой тела и контекста — это упрощает расширение набора эффектов.

## C++ Lowering Rules

`MLC::Backend::CppLowering` использует тот же rule engine, что и трансформации AST ➜ CoreIR. Стадия `:cpp_function_declaration` (правило `Rules::CodeGen::FunctionRule`) обогащает декларации C++ информацией об эффектах (`constexpr`, `noexcept`) прямо на уровне `CppAst`. Это позволяет расширять генерацию (атрибуты, диагностика, дополнительные модификаторы) без изменения внутренних методов `lower_function`.

## Stdlib Signature Registry

`StdlibSignatureRegistry` строит единую карту экспортируемых сущностей стандартной библиотеки на основе `StdlibScanner`. Реестр отдаёт `FunctionMetadata`/`TypeMetadata` вместе с исходными `AST::FuncDecl`/`AST::TypeDecl`, поэтому стадии `IRGen` могут регистрировать сигнатуры и типы без повторного чтения файлов. Это обеспечивает:

- однократный парсинг stdlib на сессию;
- единый источник квалифицированных имён (`aurora::io::println` и т. п.);
- доступ к тем же метаданным для бэкенда (C++ lowering) и инспекционных инструментов.

Правило `Rules::IRGen::StdlibImportRule` обслуживает стадию `:core_ir_stdlib_import` и, используя реестр, подключает необходимые функции и типы без прямого доступа этапов трансформации к файловой системе.

## Pass Manager

`MLC::PassManager` управляет последовательностью стадиц, из которых складывается трансформация IR. Каждая стадия получает общий контекст (импорты, таблицы типов, промежуточные результаты) и может добавлять свои правила/сервисы. Это шаг к полноценному pass managerʼу в духе LLVM/MLIR: rule engine работает внутри отдельных пассов, а порядок/конфигурация управляется централизованно.

## Event Bus

`MLC::EventBus` обеспечивает лёгкую публикацию событий (например, `:stdlib_function_imported`, `:stdlib_missing_item`). Трансформеры и правила получают ссылку на общий bus через контекст; обработчики можно подключать динамически (агентами, инструментами). Это первый шаг к полноценной telemetry/diagnostics инфраструктуре, когда каждый пасс сообщает о своём прогрессе и аномалиях.

Для отладки по умолчанию подключается `Diagnostics::EventLogger`, который пишет события в stderr. При интеграции в приложения/агентов вместо него можно зарегистрировать собственные подписчики, собирающие метрики или отображающие предупреждения в UI.

## MLC::Application

`MLC::Application` собирает общий event bus, rule engine и фабрики для `IRGen`/`CppLowering`. Он служит точкой конфигурации: агенты или host-приложения могут переопределять bus, логгер и правила до запуска пайплайна. `MLC.compile` использует `Application` по умолчанию, что гарантирует консистентный набор сервисов.
```ruby
custom_logger = ->(bus) { bus.subscribe(:type_mismatch) { |payload| warn payload.inspect } }
app = MLC::Application.new(logger: nil, subscribers: [custom_logger])
to_core = app.build_to_core
cpp = app.build_cpp_lowering(type_registry: MLC::TypeRegistry.new)
```

## Match Analyzer

`MatchAnalyzer` концентрирует всю обработку ветвей `match` (проверка согласованности типов, в перспективе – исчерпываемости). Высокоуровневое построение CoreIR теперь живёт в правиле `Rules::IRGen::MatchRule` (стадия `:core_ir_match_expr`), поэтому трансформер лишь подготавливает контекст и вызывает rule engine. Преобразование ветви (`transform_match_arm`) остаётся в трансформере, а анализ типов выполняется централизованно:

```ruby
analysis = match_analyzer.analyze(
  scrutinee_type: scrutinee.type,
  arms: ast_match.arms,
  transform_arm: method(:transform_match_arm)
)

CoreIR::Builder.match_expr(scrutinee, analysis.arms, analysis.result_type)
```

Расширение `MatchAnalyzer` предполагается через rule-сервис: правила смогут добавлять проверки (исчерпываемость, bindings) без изменения трансформера.

## Правила и эвристики

- Семантические эвристики рекомендуется оформлять в виде правил (каталог `lib/aurora/rules`).
- Правило получает контекст (`TypeContext`, `TypeRegistry`, `GenericCallResolver`) и работает поверх CoreIR.
- Регистрация правил — через фабрику, что позволит ИИ‑агентам безопасно добавлять/отключать логику.

## Инструментация

Планируется event‑bus для публикации событий вроде «конструктор Some инстанциирован», «тип T сопоставлен с i32». Это облегчит анализ и CI‑мониторинг.

## Тестовые уровни

1. **Unit** — контрактные тесты (`type_inference_architecture_test.rb`).
2. **Rule tests** — для будущего rule‑engine.
3. **Integration** — e2e (Option/Result/Generics).

## Дорожная карта

1. Перевести оставшиеся места на `TypeContext`, убрать прямой доступ к стеку.
2. Расширить `GenericCallResolver` и `MatchAnalyzer` правилами и подключить через DI к остальным частям пайплайна.
3. Добавить rule‑engine и event‑bus.
4. Создать `StdlibSignatureRegistry` для централизованного описания stdlib.

Следуя этим шагам, архитектура останется стабильной, а развитие компилятора — прозрачным для людей и ИИ‑агентов.

# Aurora Compiler Refactoring - Full Plan

**Дата начала:** 2025-10-30
**Цель:** Rules-based architecture + Professional naming (как LLVM/Rust)

## Архитектурные принципы

1. ✅ ВСЯ логика трансформации в rules (не в transformer/lowerer классах)
2. ✅ Нет DelegatingRule - только BaseRule с полной логикой
3. ✅ State через context, не через instance variables
4. ✅ Helpers только для pure functions (без state)
5. ✅ Названия как в больших компиляторах (Clang, Rust)

## Новая структура (после рефакторинга)

```
lib/aurora/
├── core_ir_gen/              (было: passes/to_core/)
│   ├── base.rb              (был: base_transformer.rb)
│   ├── helpers.rb           (НОВЫЙ - pure functions)
│   ├── type_inference.rb    (остается без изменений)
│   └── function_gen.rb      (был: function_transformer.rb)
│
├── cpp_codegen/             (было: backend/cpp_lowering/)
│   ├── base.rb             (был: base_lowerer.rb)
│   ├── helpers.rb          (уже есть)
│   ├── type_mapper.rb      (был: type_lowerer.rb)
│   └── function_gen.rb     (был: function_lowerer.rb)
│
└── rules/
    ├── core_ir/            (AST → CoreIR rules)
    └── cpp/                (CoreIR → C++ rules)
```

## Переименование классов

### Было → Станет

**Core IR generation (AST → CoreIR):**
- `Aurora::Passes::ToCore` → `Aurora::CoreIRGen`
- `ToCore::BaseTransformer` → `CoreIRGen::Base`
- `ToCore::ExpressionTransformer` → ❌ УДАЛИТЬ (логика → rules)
- `ToCore::StatementTransformer` → ❌ УДАЛИТЬ (логика → rules)
- `ToCore::FunctionTransformer` → `CoreIRGen::FunctionGen`
- `ToCore::TypeInference` → `CoreIRGen::TypeInference`
- (новый) → `CoreIRGen::Helpers`

**C++ code generation (CoreIR → C++):**
- `Aurora::Backend::CppLowering` → `Aurora::CppCodeGen`
- `CppLowering::BaseLowerer` → `CppCodeGen::Base`
- `CppLowering::ExpressionLowerer` → ❌ УДАЛИТЬ (логика → rules)
- `CppLowering::StatementLowerer` → ❌ УДАЛИТЬ (логика → rules)
- `CppLowering::FunctionLowerer` → `CppCodeGen::FunctionGen`
- `CppLowering::TypeLowerer` → `CppCodeGen::TypeMapper`
- `CppLowering::Helpers` → `CppCodeGen::Helpers`

---

# PHASE 1: C++ Backend Statement Rules (ЗАВЕРШИТЬ)

**Статус:** 15/15 expression rules ✅ | 0/10 statement rules ⏳

## 1.1. Statement Rules (0/10) - NOT STARTED

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

## 1.2. Cleanup C++ Backend (0/2)

- [ ] Удалить `lib/aurora/backend/cpp_lowering/expression_lowerer.rb` (857 строк)
- [ ] Удалить `lib/aurora/backend/cpp_lowering/statement_lowerer.rb` (331 строка)

---

# PHASE 2: ToCore Rules Refactoring

**Статус:** 0/32 rules | 0/1 helpers

## 2.1. Helpers Module (0/1) - NOT STARTED

- [ ] Создать `lib/aurora/passes/to_core/helpers.rb`
  - [ ] `describe_type(type)` - pure function
  - [ ] `normalized_type_name(name)` - pure function
  - [ ] `type_name(type)` - pure function
  - [ ] `generic_type_name?(name)` - pure function
  - [ ] `apply_type_substitutions(type, subs)` - pure function
  - [ ] `is_pure_expression(expr)` - pure function
  - [ ] `pure_block_expr?(block_expr)` - pure function
  - [ ] `pure_statement?(stmt)` - pure function
  - [ ] `io_return_type(name)` - pure function
  - [ ] `type_satisfies_constraint?(constraint, type_name)` - pure function

## 2.2. Statement Rules (0/11) - NOT STARTED

- [ ] ExprStmtRule
- [ ] VariableDeclRule
- [ ] AssignmentRule
- [ ] ForRule
- [ ] IfRule
- [ ] WhileRule
- [ ] ReturnRule
- [ ] BreakRule
- [ ] ContinueRule
- [ ] BlockRule

## 2.3. Expression Rules (0/19) - NOT STARTED

- [ ] LiteralRule
- [ ] VarRefRule
- [ ] MemberRule
- [ ] CallRule
- [ ] UnaryRule
- [ ] BinaryRule
- [ ] PipeRule
- [ ] LetRule
- [ ] RecordLiteralRule
- [ ] IfRule
- [ ] ArrayLiteralRule
- [ ] DoRule
- [ ] BlockRule
- [ ] MatchRule
- [ ] LambdaRule
- [ ] IndexAccessRule
- [ ] ForLoopRule
- [ ] WhileLoopRule
- [ ] ListComprehensionRule

## 2.4. Top-level Rules (0/2) - NOT STARTED

- [ ] SumConstructorRule
- [ ] MatchRule (top-level)

## 2.5. Cleanup ToCore (0/2)

- [ ] Удалить `lib/aurora/passes/to_core/expression_transformer.rb` (807 строк)
- [ ] Удалить `lib/aurora/passes/to_core/statement_transformer.rb` (240 строк)

---

# PHASE 3: Renaming & Restructuring

**Статус:** 0/4 modules

## 3.1. Rename ToCore → CoreIRGen (0/1)

- [ ] Переименовать `lib/aurora/passes/to_core/` → `lib/aurora/core_ir_gen/`
- [ ] Переименовать класс `Aurora::Passes::ToCore` → `Aurora::CoreIRGen`
- [ ] Обновить все require_relative пути
- [ ] Обновить все использования в коде

## 3.2. Rename CppLowering → CppCodeGen (0/1)

- [ ] Переименовать `lib/aurora/backend/cpp_lowering/` → `lib/aurora/cpp_codegen/`
- [ ] Переименовать класс `Aurora::Backend::CppLowering` → `Aurora::CppCodeGen`
- [ ] Обновить все require_relative пути
- [ ] Обновить все использования в коде

## 3.3. Rename Internal Modules (0/2)

### CoreIRGen modules:
- [ ] `BaseTransformer` → `Base`
- [ ] `FunctionTransformer` → `FunctionGen`
- [ ] `TypeInference` → `TypeInference` (без изменений)

### CppCodeGen modules:
- [ ] `BaseLowerer` → `Base`
- [ ] `FunctionLowerer` → `FunctionGen`
- [ ] `TypeLowerer` → `TypeMapper`
- [ ] `Helpers` → `Helpers` (без изменений)

---

# PHASE 4: Tests & Verification

- [ ] Запустить полный test suite после C++ statement rules
- [ ] Запустить полный test suite после ToCore rules
- [ ] Запустить полный test suite после renaming
- [ ] Убедиться что 0 failures, 0 errors

---

# PHASE 5: Documentation & Cleanup

- [ ] Обновить README с новой архитектурой
- [ ] Создать ARCHITECTURE.md с диаграммой pipeline
- [ ] Удалить старые TODO файлы (REFACTORING_TODO.md)
- [ ] Git commit + push финальной версии

---

## Текущая задача

**СЕЙЧАС:** C++ Backend Statement Rules (0/10)

**НАЧАТЬ С:** BreakRule, ContinueRule, ReturnRule (самые простые)

## Context передача

### CoreIRGen rules получают context с:
- `transformer` - для рекурсивных вызовов + state access
- `type_registry` - для TypeRegistry lookups
- `function_registry` - для function lookups
- `rule_engine` - для вложенных rules
- `loop_depth` - для проверки break/continue
- `var_types` - для type inference

### CppCodeGen rules получают context с:
- `lowerer` - для рекурсивных вызовов
- `type_map` - для map_type helper
- `type_registry` - для TypeRegistry lookups
- `function_registry` - для qualified function names
- `runtime_policy` - для стратегий lowering
- `event_bus` - для событий
- `stdlib_scanner` - для stdlib functions
- `user_functions` - для user-defined functions

---

## Прогресс

### C++ Backend
- Expression Rules: **15/15 (100%)** ✅
- Statement Rules: **0/10 (0%)** ⏳
- Cleanup: **0/2 (0%)** ⏳

### ToCore
- Helpers: **0/1 (0%)** ⏳
- Statement Rules: **0/11 (0%)** ⏳
- Expression Rules: **0/19 (0%)** ⏳
- Top-level Rules: **0/2 (0%)** ⏳
- Cleanup: **0/2 (0%)** ⏳

### Renaming
- CoreIRGen: **0/1 (0%)** ⏳
- CppCodeGen: **0/1 (0%)** ⏳
- Internal modules: **0/2 (0%)** ⏳

### Total: **15/67 tasks (22%)**

---

## Notes

### Почему такая архитектура?

Следуем примеру **LLVM** и **Rust compiler**:

**LLVM:**
- PassManager - координатор (не содержит логику)
- Individual Passes - вся логика трансформации

**Rust:**
- `rustc_ast_lowering` - AST → HIR
- `rustc_mir_build` - HIR → MIR
- `rustc_codegen_llvm` - MIR → LLVM IR

**Aurora (после рефакторинга):**
- `CoreIRGen` - координатор AST → CoreIR (state + entry points)
- `CppCodeGen` - координатор CoreIR → C++ (state + entry points)
- `Rules` - ВСЯ логика трансформации
- `RuleEngine` - диспетчер (находит и вызывает rules)

### Преимущества

1. **Тестируемость** - каждый rule тестируется независимо
2. **Расширяемость** - новые rules добавляются легко
3. **Понятность** - логика не размазана по классам
4. **Стандартность** - как в промышленных компиляторах

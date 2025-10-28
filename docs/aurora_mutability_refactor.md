# Aurora Mutability Refactor Plan

## Overview

Goal: introduce statement blocks and true mutable assignments into Aurora while preserving backwards compatibility with existing expression-oriented semantics.

Key constraints:
- Parser/AST, CoreIR, and C++ lowering currently assume pure expressions.
- `let` desugars to immediately-invoked lambdas, preventing stateful loops.
- CLI behaviour and existing scripts must keep working during migration.

This document tracks the refactor plan, status, and findings.

## Phase Tracking

| Phase | Description | Owner | Status | Notes |
| --- | --- | --- | --- | --- |
| 0 | Architectural assessment of current pipeline | Codex | In progress | Collecting module responsibilities, data-flow, assumptions |
| 1 | Semantic design of statements/mutability | Codex | Pending | Define language rules, compatibility model |
| 2 | Parser & AST extensions | Codex | Pending | Add statement nodes, revise `for` grammar |
| 3 | CoreIR redesign | Codex | Pending | Support statements, scopes, mutable vars |
| 4 | Type/effect system updates | Codex | Pending | Revisit inference and purity tracking |
| 5 | C++ lowering overhaul | Codex | Pending | Emit blocks, declarations, assignments |
| 6 | Runtime & helpers review | Codex | Pending | Ensure runtime supports new semantics |
| 7 | Test suite expansion & migration | Codex | Pending | Cover new behaviour, protect regressions |
| 8 | Documentation & rollout | Codex | Pending | Update language reference, migration guide |

## Phase 0 – Architectural Assessment (In Progress)

### Objectives
1. Map the current compilation pipeline (Parser → AST → CoreIR → CppLowering).
2. Identify locations where immutability or expression-only assumptions are hard-coded.
3. Catalogue existing helper utilities (e.g., runtime) that may need updates.

### Findings
- **Parser (`lib/aurora/parser/parser.rb`)**
  - Expressions only; no concept of statements or blocks.
  - `for ... do` parses to `AST::ForLoop` with body as a single expression.
  - No assignment node; variable names map to `AST::VarRef`.
- **AST (`lib/aurora/ast/nodes.rb`)**
  - Provides `Let`, `ForLoop`, `Lambda`, etc., but missing `Assignment`, `BlockStatement`.
  - Comments indicate `Block` and `Return`, yet parser never emits them in Aurora mode.
- **CoreIR (`lib/aurora/core_ir`)**
  - `Passes::ToCore` translates `let` to `CoreIR::LetExpr` and immediately deletes binding post-body.
  - CoreIR has only expression kinds (`BinaryExpr`, `CallExpr`, etc.); no statements or mutable vars.
  - Effects inference assumes purity, returning `[:constexpr, :noexcept]`.
- **Lowering (`lib/aurora/backend/cpp_lowering.rb`)**
  - Generates lambda IIFEs for `let` to mimic scoping.
  - For loops become range-for with body expressions wrapped in expression statements, but rely on expression-returning body.
  - No facility to emit variable declarations mid-block; uses raw statements sparingly (e.g., regex handling).
- **Runtime**
  - No direct impact from mutability yet, but expect potential additions when statements exist.

### Risks Identified
- Tight coupling between `Let` as expression and lambda lowering; removing lambda IIFE requires new IR semantics.
- Lack of distinction between statements and expressions means large AST/IR surgery.
- Effect system and template generation may break when functions become impure by default.

### Next Steps
- Document data flow diagrams (parser output → CoreIR structure).
- Extract representative examples demonstrating current limitations (e.g., `for` + `let`).
- Prepare compatibility test list that must stay green after refactor.

## Phase 0.1 – Data Flow Mapping

### Compilation Stages (Current)

1. **Parser (`Aurora.parse`)**
   - `Parser::Parser#parse` builds `Aurora::AST::Program`.
   - Expressions only; `let`, `for`, `match` return expression nodes.
   - `for` → `AST::ForLoop` with `body` = expression.

2. **CoreIR Transformation (`Aurora.transform_to_core`)**
   - `Passes::ToCore#transform` traverses AST.
- `AST::Let` lowered до unit-valued `BlockExpr` с `CoreIR::VariableDeclStmt` внутри; binding type хранится в `@var_types`.
- `AST::ForLoop` -> `CoreIR::ForStmt` (через блок-обёртку для expression-кейсов), `AST::WhileLoop` -> `CoreIR::WhileStmt`.
- `AST::MatchExpr` → `CoreIR::MatchStmt` для unit-веток (через блок-обёртку), иначе остаётся выражением.
   - Statement-путь закрывает `VariableDecl`, `Assignment`, `Return`, `Break/Continue`.

3. **C++ Lowering (`Aurora.lower_to_cpp`)**
   - `Backend::CppLowering#lower_module` returns `CppAst::Nodes::Program`.
   - `CoreIR::VariableDeclStmt` → обычные объявления/`auto`, `ForStmt` → `for (T var : container) { ... }` без лямбда-IIFE.
   - `CoreIR::BlockExpr` всё ещё по умолчанию сворачивается в `[&]() { ... }()` если нужно значение.

4. **Code Emission (`CppAst::Nodes#to_source`)**
   - Serialises to C++.
   - Because of lambda/IIFE desugaring, generated code contains nested `[&]() { ... }()` constructs.

### Key Couplings to Address
- `CoreIR::LetExpr` остаётся в AST ради обратной совместимости; нужно полностью перевести старые call-sites на statement-блоки.
- `CoreIR::BlockExpr` → `lower_block_expr` всё ещё генерирует `[&]() { ... }()` для получения значения; требуется единая стратегия без IIFE.
- `Backend::CppLowering#lower_record` недавно переведён на brace-init, но остальной backend всё ещё оптимизирован под expression-модель.
- Эффект-система (`EffectAnalyzer`) по умолчанию помечает `BlockExpr` как импьюрный, что ломает `:constexpr` для чистых блоков.

## Phase 0.2 – Example Reproduction

Using the current compiler:

```aurora
fn main() -> i32 =
  for line in ["x"] do
    let total = 0
    total + 1
```

- `let total = 0` works once, but any attempt to introduce `total = total + 1` results in parse error (`Unexpected token: EQUAL`).
- Even with `let` inside the loop, the lambda desugaring prevents state from carrying across iterations.

CLI example demonstrating unmet use case:

```
$ cat <<'AUR' | bin/aurora -
fn main() -> i32 =
  for line in ["x"] do
    total = 0
    total + 1
AUR
Parse error: Unexpected token: EQUAL(=)
```

This script is representative of the desired behaviour the refactor must enable.

### Compatibility Test Baseline
- All existing `bundle exec rake test` suites must remain green.
- CLI integration tests (`test/integration/aurora_cli_test.rb`) will be extended but must continue to pass legacy scenarios (`println`, arrays, regex, map/filter/fold).

## Phase 1 – Semantic Design (Draft)

### Goals
- Introduce explicit **statements** alongside expressions.
- Support **mutable bindings** and **assignments** while preserving existing expression-only constructs.
- Allow blocks to combine statements and produce optional final expressions (`{ stmt*; expr }`).
- Maintain backwards compatibility: expression bodies should continue to compile without modification.

### Proposed Language Constructs

1. **Variable Declarations**
   - Immutable by default: `let total = 0`
   - Mutable form: `let mut total = 0`
   - Scope: block-scoped; redeclaration of the same name in inner block shadows outer binding.

2. **Assignment Statement**
   - Syntax: `<identifier> = <expression>;`
   - Allowed only for variables declared `mut`.
   - Evaluated as statement (no value produced).

3. **Blocks**
   - `{ statement* expression? }`
   - If the final expression is present, block evaluates to its value; otherwise returns `void`.
   - Blocks may appear wherever expressions are accepted (to preserve compatibility).

4. **For Loop**
   - `for item in iterable do { ... }`
   - Body requires block. Single-expression shorthand remains valid: `for item in iterable do expr` desugars to `{ expr }`.
   - Loop variable is immutable unless explicitly declared mutable inside loop (e.g., `let mut item = item`).

5. **While Loop (Optional Extension)**
   - Consider introducing `while condition do { ... }` for parity; depends on implementation complexity.

6. **Return Statement**
   - Explicit `return expr;` inside blocks/functions; helps exit early from loops.

### Semantics & Evaluation Rules

- **Evaluation order**: statements execute top-to-bottom; assignments mutate existing storage.
- **Expressions vs. statements**: maintain expression-based code path; when encountering `let`, generate statement for declaration but allow expression form via `{ let mut x = ...; ...; x }`.
- **Purity / Effects**: functions containing assignments are no longer `constexpr`; adjust effect inference.
- **Desugaring (legacy scripts)**: existing `let` expressions still lower to lambda IIFEs until full migration, but new AST must differentiate between expression-let and statement-let.

### Open Questions
- Should mutable variables require explicit `mut`, or adopt a different keyword?
- How to handle assignment within pattern matching arms?
- Do we allow implicit block creation in `if` branches (`if cond then stmt else stmt`), or require braces?
- Interaction with current type inference when mutation occurs (e.g., `let mut count = 0; count = count + 1;`).

### Next Actions
- Finalise mutable declaration syntax (`let mut` vs. `var`).
- Decide on block-return semantics and whether trailing expression is mandatory for expression contexts.
- Define migration strategy for existing `let` expressions (hybrid mode vs. full rewrite).

## Phase 2 – Parser & AST Preparation

### Current Parser Capabilities
- Expressions only; `parse_expression` recursively handles literals, `let`, `if`, `match`, `for` (as sugar).
- No token handling for `mut` keyword or assignment operator `=`.

### Required Grammar Extensions

1. **Keywords & Tokens**
   - Add `mut` keyword (`Lexer::KEYWORDS`).
   - Differentiate assignment `=` from equality; currently `=` used for function body and let binding.
   - Introduce semicolon `;` as statement separator inside blocks (currently exists but rarely used).

2. **New AST Nodes**
   - `AST::Assignment` (fields: `target`, `value`).
   - `AST::BlockStatement` / reuse existing `AST::Block` but ensure parser emits it.
   - `AST::VariableDecl` (mutable flag, name, initializer).
   - `AST::ExpressionStatement` for wrapping expressions inside blocks.

3. **Block Parsing**
   - Extend `parse_primary` to recognise `{` as block entry and parse sequence:
     ```
     { statement* expression? }
     ```
   - Statements within block can be:
     - Variable declaration (`let` / `let mut`).
     - Assignment (`identifier = expr;`).
     - Expression statement (`expr;`).
     - Nested block (`{ ... }`).
     - Control statements (`return`, `if`, `for`) either as statements or expressions.

4. **Let Handling**
   - `let` becomes statement when followed by `;` or inside block.
   - Expression form `let x = expr; body` remains valid via desugaring to block:
     ```
     let x = expr
     body
     ```
     would parse as block containing declaration and trailing expression.

5. **For Loop**
   - Body parsing should accept block; if expression encountered, wrap into block.
   - Example:
     - `for x in list do expr` → `Block` with single expression statement returning expr.
     - `for x in list do { ... }` → block as-is.

### AST Updates Needed
- Modify `AST::Let` to carry mutability flag and possibly statement/expression context.
- Potentially introduce `AST::Statement` base class to organise new nodes.
- Ensure existing nodes (`AST::Block`, `AST::ExprStmt`) are fleshed out and used.

### Parser Task List
- [ ] Add `mut` to lexer keywords.
- [ ] Split assignment parsing from binary equality.
- [ ] Implement block parsing with statement list.
- [ ] Create parser methods: `parse_statement`, `parse_variable_decl`, `parse_assignment`.
- [ ] Update `parse_for_loop` to consume block body.
- [ ] Additional tests in `test/aurora/parser` covering new grammar.

### Risks
- Introducing `mut` requires verifying no conflicts with existing grammar.
- Distinguishing between expression `=` (function definition) and assignment `=` may require token lookahead logic.
- Need to maintain expression compatibility to avoid breaking current code.

## Phase 3 – CoreIR Redesign (Draft)

### Objectives
- Extend CoreIR with statement-aware nodes while keeping expression-only lowering functional during migration.
- Track mutability and scopes, enabling later code generation of real assignments.
- Provide a compatibility path by desugaring “pure expression” blocks back to existing constructs where possible.

### Proposed CoreIR Additions

| Node | Purpose | Notes |
| --- | --- | --- |
| `CoreIR::BlockStmt` | Sequence of statements optionally yielding final expression | Holds vector of `Stmt` nodes plus optional tail expression |
| `CoreIR::VariableDeclStmt` | Mutable/immutable variable declaration | Fields: `name`, `type`, `value`, `mutable` flag |
| `CoreIR::AssignmentStmt` | Mutation of an existing binding | Fields: `target`, `value` |
| `CoreIR::ReturnStmt` (optional) | Early exit in block/function | Useful once blocks support statements |
| `CoreIR::ExprStmt` | Wrap expression used as statement | Bridge for compatibility |
| `CoreIR::ForStmt` | Statement form of `for` | Полностью заменяет прежний `ForLoopExpr` выражений |

Legacy expression nodes (`LetExpr`) остаются ради совместимости, но постепенно сводятся к statement-блокам:
- `LetExpr` → Declaration + block (уже реализовано через `BlockExpr`).

**Status:** statement nodes подключены, блоки и мутабельные присваивания уже работают, но остаются задачи:
- Переписать `LetExpr` на statement-based lowering (Phase 3b).
- Расширить statement-поддержку на `if`/`else`, `while` и другие конструкции; в expression-контексте оставить тонкий слой совместимости.
- Доработать lowering, чтобы expression-`for` тоже выдавал корректный `return` без искусственных лямбд.
- Проработать «честный» statement-путь для функций с несколькими блоками (фазовый переход к полноценному AST → CoreIR statements → C++ statements).

#### Самые сложные хвосты
- **Match как выражение.** Для веток с `unit` уже используем `MatchStmt`; остаётся общий переход на statement-пайплайн для выражений, где нужен результат, и зачистка IIFE.
- **Анализ эффектов.** `TypeSystem::EffectAnalyzer` маркирует любой `BlockExpr` как импьюрный. После перехода на statement-пайплайн придётся заново определить критерии `:constexpr`, иначе функции теряют оптимизации.
- **Граница expression/statement.** Парсер пока разрешает смешанные ветки (`if`/`match` с выражением и statement). Требуется финальный проход по грамматике, чтобы явно фиксировать statement-контексты.
- **Backend без неявных `return`.** `lower_block_expr` и смежные пути добавляют `return` для хвостового выражения. Для statement-блоков нужен чистый список операторов, иначе остаются лишние `return`.
- **Документация и e2e-тесты.** После завершения миграции нужно обновить CLI/интеграционные проверки и языкосправочники, чтобы описывать реальные блоки и мутабельность, а не legacy do-выражения.

### Transformation Strategy (AST → CoreIR)
1. **Context Tracking**
   - Maintain environment stack with mutability info.
   - On encountering `AST::VariableDecl`, emit new `CoreIR::VariableDeclStmt`.
   - For `AST::Assignment`, ensure target was declared mutable; otherwise raise compile error.

2. **Hybrid Mode**
   - When block contains only expression statements, continue emitting expression tree (current behaviour).
   - For mixed statements, convert to `CoreIR::BlockStmt` and mark enclosing function as "impure" (affects effect inference).
   - Provide temporary lowering that converts `BlockStmt` back into nested lambda/IIFEs so runtime behaviour stays unchanged until C++ lowering is updated.

3. **Let Compatibility**
   - `AST::Let` (expression form) remains available; new parser statement `VariableDecl` gives path to proper block semantics.
   - Ensure both converge to same IR eventually to avoid divergent code paths.

### Effect System Adjustments
- Any block containing assignment should drop `:constexpr` effect.
- Introduce a new `:impure` or similar tag to inform later lowering decisions.
- ✅ Блоки с только неизменяемыми declarations и чистыми выражениями теперь считаются `:constexpr` (анализатор эффектов смотрит на statements).

### Migration Steps
1. Implement new CoreIR statement nodes with builders.
2. Update `Passes::ToCore` to emit them while preserving legacy path. ✅
3. Retrofit existing tests by ensuring expression-only scripts still compile. ✅
4. Create new unit tests validating: ✅
   - Mutable declaration/assignment raise or succeed appropriately.
   - Mixing immutable + mutable in same scope works.
   - Blocks with trailing expression produce expected CoreIR structures.
5. Implement statement-aware lowering paths for loops/functions.

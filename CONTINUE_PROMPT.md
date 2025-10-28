# Aurora Mutability Refactor – Next Steps Prompt

Context: Aurora’s compiler is mid-transition from an expression-only pipeline to a statement-aware one. Loops now lower to statement IR (`CoreIR::ForStmt`/`WhileStmt`) and emit straight C++ blocks; `match` with unit arms is also statement-backed (`MatchStmt`). `AST::Let` and legacy `do` blocks normalize into `AST::BlockExpr` + statement lists, and loop-specific lambda IIFEs are gone. Remaining IIFEs come from `lower_block_expr` when a block must yield a value. The effect system can now mark simple statement blocks as `:constexpr`, but more complex purity still needs work. Parser is mostly normalized, yet expression-path fallbacks (especially for value-returning `match`/`BlockExpr`) still exist, and documentation/tests should reflect the statement-first semantics.

Goals for the next session:
1. Remove the remaining `[&]() { … }()` IIFEs by teaching `lower_block_expr` (and any call sites) to emit straight statements with optional temporary/return plumbing when a value is required.
2. Extend `TypeSystem::EffectAnalyzer` beyond the simple cases to keep functions `:constexpr` when statement blocks remain pure (guards, nested matches, etc.).
3. Tighten parser + ToCore handling for the remaining expression fallbacks (value-returning `match`, generic `BlockExpr` usage) so the statement pipeline is authoritative.
4. Refresh docs/tests/integration fixtures to match the statement-first semantics (no references to legacy expression IR; document MatchStmt and the new behaviour).

Constraints:
- Reuse the existing rule-engine infrastructure for statements.
- Maintain the current passing test suite; add tests on changed behaviour (constexpr detection, block codegen).
- Keep edits surgical (apply_patch suggested) and comments concise.

Suggested priority order:
1. Rewrite `lower_block_expr` to drop lambda IIFEs and handle value-returning statement blocks.
2. Redefine the effect analyzer for statement-backed purity to restore `:constexpr`.
3. Lock down parser/ToCore for `if`/`match` branching semantics.
4. Perform a documentation & integration/CLI test sweep to reflect the new architecture.

  1. value-блоки без IIFE – lower_block_expr всё ещё генерирует [&]() { … }() для выражений, где нужен результат. Чтобы избавиться, придётся вводить временные переменные и переписывать все expression-кейсы. Это большая итерация, лучше идти отдельно.
  2. Расширенный анализ эффектов – мы научили его распознавать чистые блоки и MatchStmt, но вызовы/guards и более сложные комбинации всё ещё требуют ручной проверки. Можно заняться оптимизацией и точностью (прописать, какие функции считать чистыми, как вести себя с guard’ами).
  3. Документация и CLI/интеграционные тесты – нужно пройтись по примерам, README, справке по синтаксису, чтобы показывать statement-блоки и MatchStmt как основную модель (а legacy do/IIFE — как феномен прошлого).
  4. Грамматика if/match – мы нормализовали AST, но синтаксис ещё позволяет старые формы (then, do). Если хотим новый “чистый” синтаксис, стоит спланировать отдельную фазу с обновлением парсера и тестов.


# Changelog

## 2025-01-14 - Trivia in Tokens Verification & CST 10/10

### Major Achievement
- **Trivia in Tokens**: Подтверждена полная реализация lossless CST архитектуры ✅
- **CST Compliance**: 9/10 → **10/10** (полное соответствие эталону)

### Added
- **Verification tests** (`test/lexer/trivia_in_tokens_test.rb`): 12 новых тестов
  - Token с leading/trailing trivia
  - Множественные токены с trivia
  - Комментарии (line и block)
  - Preprocessor директивы
  - EOF token с accumulated trivia
  - Reconstruction из токенов
  
- **Demo** (`demo_trivia_in_tokens.rb`): Наглядная демонстрация работы trivia в токенах
- **Report** (`TRIVIA_COMPLETION_REPORT.md`): Полный отчёт о реализации

### Updated
- README.md: CST compliance 10/10, тесты 641 → 653
- docs/TRIVIA_IN_TOKENS_ROADMAP.md: Все чекбоксы отмечены как выполненные

### Performance
- buffer.hpp (82 строки): 4.58 мс
- texture_atlas.hpp (114 строк): 18.26 мс  
- shader.hpp (75 строк): 4.58 мс

### Statistics
- Tests: 641 → **653 (+12)**
- Assertions: 817 → **863 (+46)**
- Failures: **0** ✅

---

## 2025-01-14 - DSL Roundtrip Improvements & Edge Cases

### Fixed
- **DSL roundtrip bug**: Fixed `program()` method to correctly add trailing `"\n"` by default
- **Demo roundtrip**: `demo_dsl_roundtrip.rb` now shows ✓ Perfect roundtrip for all examples

### Added
- **For loop tests**: Added roundtrip tests for classic and range-based for loops
- **Edge cases tests** (`test/integration/edge_cases_test.rb`): 21 new tests
  - Empty files and whitespace-only files
  - Unix/Windows/mixed line endings
  - Unicode in comments and strings (including emoji 🚀)
  - Deep nesting (blocks and expressions)
  - Tabs and mixed whitespace
  - No trailing newline cases
  - Special characters in comments
  - Very long lines (1000+ characters)

### Changed
- Updated test suite: 618 → 641 tests (+23)
- Updated assertions: 794 → 817 (+23)
- All tests passing: 0 failures, 0 errors

### Documentation
- Updated README.md with new test count (641 tests)
- Added edge cases coverage to architecture status

## Previous Releases
See `BIDIRECTIONAL_DSL_MILESTONE.md` for DSL implementation details
See `FINAL_STATUS_2025.md` for overall project status


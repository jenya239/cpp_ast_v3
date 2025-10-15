# Changelog

## 2025-01-15 - Architectural Whitespace Fix

### Major Achievement
- **Fixed whitespace architecture**: 113 → 68 test failures (46 tests fixed, 41% improvement) ✅
- **Removed dual whitespace insertion**: Parser and to_source no longer duplicate space insertion
- **Documentation cleanup**: Removed 13 obsolete docs, streamlined to 4 essential files

### Changed
- **Parser** (`lib/cpp_ast/parsers/declaration/function.rb`): Move space from modifiers_text to rparen_suffix
- **Node to_source** (`lib/cpp_ast/nodes/statements.rb`): Remove all explicit space insertions
- **DSL Builder** (`lib/cpp_ast/builder/formatting_context.rb`): Set rparen_suffix=" " for pretty mode
- **Fluent API** (`lib/cpp_ast/builder/fluent.rb`): Simplify modifier spacing logic

### Added
- **ARCHITECTURE_WHITESPACE_GUIDE.md**: Complete guide to whitespace management with troubleshooting
- **docs/README.md**: Updated with current status and quick start examples

### Removed
- 13 outdated documentation files (DSL_ANALYSIS_FINAL, DSL_BENEFITS, etc.)
- 3 obsolete status reports (FINAL_FORMATTING_STATUS, FORMATTING_ISSUES, etc.)

### Statistics
- Tests: 890/958 passing (68 failures)
- Architecture: Whitespace management now consistent between parser and DSL
- Documentation: 18 → 4 core docs files

---

## 2025-01-14 - Trivia in Tokens Verification & CST 10/10

### Major Achievement
- **Trivia in Tokens**: Confirmed full lossless CST architecture implementation ✅
- **CST Compliance**: 9/10 → **10/10** (full compliance with reference architecture)

### Added
- **Verification tests** (`test/lexer/trivia_in_tokens_test.rb`): 12 new tests
  - Token with leading/trailing trivia
  - Multiple tokens with trivia
  - Comments (line and block)
  - Preprocessor directives
  - EOF token with accumulated trivia
  - Reconstruction from tokens

- **Demo** (`demo_trivia_in_tokens.rb`): Visual demonstration of trivia in tokens
- **Report** (`TRIVIA_COMPLETION_REPORT.md`): Complete implementation report

### Updated
- README.md: CST compliance 10/10, tests 641 → 653
- docs/TRIVIA_IN_TOKENS_ROADMAP.md: All checkboxes marked complete

### Performance
- buffer.hpp (82 lines): 4.58 ms
- texture_atlas.hpp (114 lines): 18.26 ms
- shader.hpp (75 lines): 4.58 ms

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
  - Unicode in comments and strings (including emoji)
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

---

## Previous Releases
See git history for earlier changes.

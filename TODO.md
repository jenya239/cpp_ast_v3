# TODO - CppAst v3

## Current Status
- **Tests:** 890/958 passing (68 failures)
- **Whitespace architecture:** ✅ Fixed (113 → 68 failures)

## High Priority (Remaining Test Failures)

### 1. Match Expression Indentation (13 tests)
Add proper indentation for lambda arms in std::visit:
```cpp
std::visit(overloaded{
  [&](const Circle& circle) { ... },  // Need leading indent
  [&](const Rect& rect) { ... }
}, shape)
```
**Files:** `lib/cpp_ast/nodes/match_nodes.rb`

### 2. Aurora Field Order (3 tests)
Fix field_def parameter order:
- Current: `field_def(type, name)`
- Expected: `field_def(name, type)`

**Files:** `lib/cpp_ast/builder/dsl.rb:541`, `lib/cpp_ast/nodes/statements.rb:674`

### 3. Nested Namespace Generation (1 test)
Add braces for nested namespaces:
```cpp
// Expected: namespace Outer { namespace Inner { ... } }
// Current:  namespace Outer namespace Inner ...
```
**Files:** `lib/cpp_ast/nodes/statements.rb:295-300`

### 4. Error Handling (6 tests)
Add input validation in DSL methods:
- Check for nil parameters
- Validate modifier combinations
- Better error messages

**Files:** `lib/cpp_ast/builder/dsl.rb`

### 5. DSL Generator Edge Cases (~40 tests)
Various DSL generator issues with:
- Complex nested structures
- Multiple modifiers
- Control flow statements

**Files:** `lib/cpp_ast/builder/dsl_generator.rb`

## Medium Priority

### Documentation
- [ ] Add examples to README.md
- [ ] Document common patterns
- [ ] Add troubleshooting guide

### Testing
- [ ] Add more edge case tests
- [ ] Improve error messages
- [ ] Add performance benchmarks

## Low Priority

### Parser Extensions (Future)
- [ ] C++20 concepts
- [ ] C++20 modules
- [ ] C++20 coroutines
- [ ] Better template parsing

## Completed ✅
- [x] Fix architectural whitespace issues (46 tests fixed)
- [x] Clean up outdated documentation
- [x] Create ARCHITECTURE_WHITESPACE_GUIDE.md
- [x] Remove duplicate documentation files

## Reference
See `/home/jenya/workspaces/.cursor/plans/cpp-ast-911b689a.plan.md` for detailed analysis.

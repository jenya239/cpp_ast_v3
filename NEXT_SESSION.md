# Next Session: ToCore Refactoring

**Дата:** 2025-10-30
**Предыдущая сессия:** C++ Backend Cleanup (COMPLETED)

## ✅ Completed in Previous Session

### C++ Backend Rules Refactoring (100%)
- **All 25 rules refactored**: 15 expression + 10 statement rules
- **Cleanup completed**: Removed 1066 lines of fallback code
- **Bug fixed**: Rules now always registered properly
- **Code reduction**:
  - ExpressionLowerer: 858→60 lines (93% reduction)
  - StatementLowerer: 332→80 lines (76% reduction)
- **Tests**: aurora_xqr_test 18/18 passing (was 2 failures)

### Commits Made
1. `refactor(cleanup): Remove fallback code from C++ lowerer modules`
2. `docs: Update REFACTORING_TODO with cleanup completion status`

## 🎯 Next Task: ToCore Refactoring

### Current ToCore Structure
```
lib/aurora/passes/to_core/
├── base_transformer.rb         (308 lines)
├── expression_transformer.rb   (807 lines)  ← REFACTOR
├── statement_transformer.rb    (240 lines)  ← REFACTOR
├── function_transformer.rb     (594 lines)  ← REFACTOR
├── type_inference.rb           (476 lines)
└── type_context.rb            (51 lines)
TOTAL: 2476 lines
```

### Refactoring Plan (Based on C++ Backend Success)

#### Phase 1: Create Helpers Module (Similar to CppLoweringHelpers)
**File**: `lib/aurora/passes/to_core/helpers.rb`

**Pure Functions to Extract**:
1. Type manipulation helpers (from type_inference.rb)
2. AST node builders (common patterns)
3. Identifier/name helpers
4. Pattern matching helpers

#### Phase 2: Create Rules Architecture
**Directory**: `lib/aurora/passes/to_core/rules/`

**Expression Rules** (~19 rules to create):
- `expression/literal_rule.rb`
- `expression/binary_rule.rb`
- `expression/unary_rule.rb`
- `expression/var_rule.rb`
- `expression/call_rule.rb`
- `expression/member_rule.rb`
- `expression/if_rule.rb`
- `expression/match_rule.rb`
- `expression/lambda_rule.rb`
- `expression/array_rule.rb`
- `expression/record_rule.rb`
- `expression/index_rule.rb`
- `expression/block_rule.rb`
- `expression/list_comp_rule.rb`
- etc.

**Statement Rules** (~11 rules to create):
- `statement/expr_statement_rule.rb`
- `statement/variable_decl_rule.rb`
- `statement/assignment_rule.rb`
- `statement/return_rule.rb`
- `statement/break_rule.rb`
- `statement/continue_rule.rb`
- `statement/if_rule.rb`
- `statement/while_rule.rb`
- `statement/for_rule.rb`
- `statement/match_rule.rb`
- etc.

#### Phase 3: Update Main ToCore Class
**File**: `lib/aurora/passes/to_core.rb`

Changes needed:
1. Register all ToCore rules in `initialize` or `register_to_core_rules` method
2. Keep coordinator methods (`transform_expression`, `transform_statement`)
3. Remove delegating logic (let rules handle everything)

#### Phase 4: Cleanup
1. Delete `expression_transformer.rb` (807 lines)
2. Delete `statement_transformer.rb` (240 lines)
3. Delete `function_transformer.rb` (594 lines)
4. Update `base_transformer.rb` to only contain coordinator logic
5. Run full test suite

#### Phase 5: Renaming (Final Step)
1. Rename `Aurora::Passes::ToCore` → `Aurora::CoreIRGen`
2. Rename `Aurora::Backend::CppLowering` → `Aurora::CppCodeGen`
3. Update all imports and references
4. Run full test suite

## 📊 Expected Results

**Code Reduction Estimate** (based on C++ backend results):
- expression_transformer: 807 → ~80 lines (~90% reduction)
- statement_transformer: 240 → ~50 lines (~80% reduction)
- function_transformer: 594 → keep as-is (handles function-level logic)
- **Total reduction**: ~900-1000 lines

**Architecture Benefits**:
- ✅ Declarative rules instead of case statements
- ✅ Each rule self-contained and testable
- ✅ Clear separation: rules contain logic, transformers coordinate
- ✅ Matches LLVM/Rust compiler architecture patterns

## 🚀 How to Start Next Session

### Step 1: Create Helpers Module
```bash
# Analyze type_inference.rb and base_transformer.rb
cat lib/aurora/passes/to_core/type_inference.rb | head -50
cat lib/aurora/passes/to_core/base_transformer.rb | head -50

# Create helpers module
mkdir -p lib/aurora/passes/to_core/rules
touch lib/aurora/passes/to_core/helpers.rb
```

### Step 2: Extract Pure Functions
Identify and extract stateless helper functions:
- Type construction helpers
- AST node builders
- Validation helpers

### Step 3: Start with Simple Rules
Begin with simple expression rules (similar to C++ backend approach):
1. LiteralRule
2. VarRule
3. BinaryRule
4. UnaryRule

### Step 4: Batch Refactoring
Work in batches of 3-5 rules, running tests after each batch.

## 📝 Notes for Next Session

### Key Learnings from C++ Backend
1. **Always register rules in initialize** - Don't rely on external registration
2. **Use context hash** - Pass dependencies via context instead of instance variables
3. **Recursive calls via transformer** - Pass `transformer` in context, call `transformer.send(:transform_expression, node)`
4. **Helper methods stay in transformer** - Keep complex coordinator logic in transformer modules
5. **Test after each batch** - Don't batch too many changes before testing

### Potential Challenges
1. Type inference integration - ToCore has complex type inference that C++ backend doesn't have
2. Function transformer - May need special handling for function-level transformations
3. More complex AST nodes - Aurora AST may be more complex than CoreIR

### Success Criteria
- [ ] All tests pass (0 failures, 0 errors)
- [ ] Code reduction of 900-1000 lines
- [ ] Clear rules-based architecture
- [ ] No case statements in transformers
- [ ] All logic encapsulated in rules

## 🎯 Final Goal

Transform ToCore from imperative transformer architecture to declarative rules-based architecture, matching the clean design achieved in C++ backend refactoring.

**Target Date**: 2025-10-31
**Estimated Time**: 3-4 hours (based on C++ backend experience)

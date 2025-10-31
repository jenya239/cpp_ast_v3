# Rule Engine Roadmap

## ✅ Completed Refactoring (2025-10-31)

### Rules-Based Architecture - 100% Complete
- **IRGen Rules** (AST → CoreIR): 26/26 rules implemented
  - 16 expression rules: literal, binary, call, match, lambda, etc.
  - 10 statement rules: variable_decl, assignment, if, for, while, etc.
  - Module renamed: `Aurora::Rules::CoreIR` → `Aurora::Rules::IRGen`
- **CodeGen Rules** (CoreIR → C++): 25/25 rules implemented
  - 15 expression rules: literal, binary, call, match, lambda, etc.
  - 10 statement rules: variable_decl, assignment, if, for, while, etc.
  - Module renamed: `Aurora::Rules::Cpp` → `Aurora::Rules::CodeGen`
- **Architecture**: All transformation logic now lives in rules (LLVM/Rust style)
- **Test Coverage**: 401 Aurora tests passing, 0 failures, 0 errors

## Core Subsystems (Production Ready)

### 1. Pattern Matching (`match`)
- ✅ `MatchRule` integrated at `:core_ir_match_expr` stage
- ✅ `MatchAnalyzer` orchestrates match arm collection and type checking
- ✅ Sum type destructuring and binding registration
- ✅ Lowering to `std::visit` with overloaded lambdas (C++)
- **Future**: Exhaustiveness checking, unreachable pattern warnings, event bus integration

### 2. Type Unification & Generics
- ✅ `TypeConstraintSolver` handles type inference and constraint solving
- ✅ `GenericCallResolver` resolves generic function calls
- ✅ Support for `<T>`, `<T, E>` type parameters
- **Future**: User-defined type constraints beyond `Numeric`

### 3. Effect System (`constexpr`, `noexcept`)
- ✅ `EffectAnalyzer` service in `Aurora::TypeSystem`
- ✅ `FunctionEffectRule` marks functions with effects at `:core_ir_function` stage
- ✅ Purity analysis for statement blocks
- **Future**: Side-effect tracking (`io`, `panic`), event bus integration

### 4. Standard Library
- ✅ `StdlibSignatureRegistry` provides metadata from `StdlibScanner`
- ✅ `StdlibImportRule` imports functions/types via `:core_ir_stdlib_import` stage
- ✅ Automatic function resolution and C++ qualified name mapping
- **Future**: Selective imports, type-only imports, validation rules, instrumentation

## Architecture Principles

### LLVM/Rust-Style Design
1. ✅ **All logic in rules** - No delegation to transformer/lowerer classes
2. ✅ **BaseRule pattern** - Self-contained rules with `applies?` and `apply`
3. ✅ **State via context** - No instance variables, pure transformation
4. ✅ **Helpers for pure functions** - Utility methods without state
5. ✅ **Professional naming** - `irgen` (IR Generation), `codegen` (Code Generation)

### Event Bus Integration
- Event bus available for all rules
- Rules can publish transformation events
- Supports logging, diagnostics, and custom instrumentation
- **Future**: Subscriber system for warnings/errors

## Next Priorities

### 1. Enhanced Match Analysis
- Exhaustiveness checking for sum types
- Dead branch detection and warnings
- Event publication for pattern matching diagnostics

### 2. Type Constraint Extensions
- User-defined type constraints
- Constraint validation rules
- Better error messages for constraint violations

### 3. Event Bus Expansion
- Subscriber registration for effect/type rules
- Rich diagnostic events with source locations
- Performance profiling hooks

### 4. Stdlib Extensions
- Import validation rules
- Selective import support (functions, types, specific items)
- Better error messages for missing imports

### 5. Optimization Rules
- Constant folding
- Dead code elimination
- Inline expansion for simple functions

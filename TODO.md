# TODO - CppAst v3

## Current Status
- **Tests:** 958/958 passing (0 failures) ✅
- **C++ AST DSL:** Production ready
- **Aurora Language:** MVP stage - basic features working

## High Priority (Aurora Language Features)

### 1. Sum Types (Algebraic Data Types)
Implement tagged unions / variant types:
```aurora
type Shape = Circle(f32) | Rect(f32, f32) | Point
```
→ Lowers to `std::variant<Circle, Rect, Point>` in C++

**Tasks:**
- [ ] Add SumType AST node
- [ ] Parser support for `Type = Variant1(...) | Variant2(...)`
- [ ] CoreIR representation
- [ ] Lowering to C++ `std::variant`
- [ ] Constructor functions for each variant

### 2. Pattern Matching
Enable exhaustive pattern matching on sum types:
```aurora
fn area(s: Shape) -> f32 =
  match s {
    Circle(r) => 3.14 * r * r,
    Rect(w, h) => w * h,
    Point => 0.0
  }
```
→ Lowers to `std::visit` with lambda overload set

**Tasks:**
- [ ] Add Match expression AST node
- [ ] Parser support for `match expr { pattern => expr, ... }`
- [ ] Pattern destructuring
- [ ] Exhaustiveness checking
- [ ] Lowering to `std::visit` with overloaded lambdas

### 3. Generic Types (Templates)
Type parameters for functions and types:
```aurora
fn identity<T>(x: T) -> T = x
type Result<T, E> = Ok(T) | Err(E)
```

**Tasks:**
- [ ] Generic function declarations
- [ ] Generic type definitions
- [ ] Type parameter constraints
- [ ] Monomorphization or template lowering

### 4. Lambda Expressions
First-class functions:
```aurora
fn map<T, R>(arr: T[], f: T => R) -> R[] = ...
let double = x => x * 2
```

**Tasks:**
- [ ] Lambda syntax parsing
- [ ] Closure capture analysis
- [ ] Lowering to C++ lambdas
- [ ] Function type signatures

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
- [x] Fix friend declaration whitespace (2025-10-17)
- [x] Fix override/final modifiers spacing (2025-10-17)
- [x] All 958 tests passing (2025-10-17)

## Reference
See `/home/jenya/workspaces/.cursor/plans/cpp-ast-911b689a.plan.md` for detailed analysis.

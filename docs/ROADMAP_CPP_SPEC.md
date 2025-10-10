# Roadmap: Full C++ Specification Coverage

## Phase 1: Expressions ✅ (MVP DONE)
- [x] Binary operators (+, -, *, /, =)
- [x] Operator precedence
- [ ] Unary operators (!, ~, ++, --, +, -, *, &)
- [ ] Comparison (==, !=, <, >, <=, >=)
- [ ] Logical (&&, ||)
- [ ] Bitwise (&, |, ^, <<, >>)
- [ ] Compound assignment (+=, -=, *=, /=, %=, &=, |=, ^=, <<=, >>=)
- [ ] Ternary (?:)
- [ ] Comma operator
- [ ] Parenthesized expressions
- [ ] Array subscript ([])
- [ ] Member access (., ->)
- [ ] Scope resolution (::)
- [ ] Function calls
- [ ] Cast expressions
- [ ] sizeof, alignof
- [ ] new, delete
- [ ] Lambda expressions

## Phase 2: Literals & Types
- [x] Number literals (basic)
- [ ] Hex/octal/binary numbers (0x, 0, 0b)
- [ ] Float literals (3.14f, 1.0e10)
- [ ] Character literals ('a', '\n')
- [ ] String literals ("hello", R"(raw)")
- [ ] Boolean literals (true, false)
- [ ] nullptr
- [ ] User-defined literals (123_km)

## Phase 3: Statements ✅ (Partial)
- [x] Expression statements
- [x] Return statements
- [ ] If/else statements
- [ ] Switch/case statements
- [ ] While loops
- [ ] Do-while loops
- [ ] For loops
- [ ] Range-based for
- [ ] Break/continue
- [ ] Goto/labels
- [ ] Try/catch/throw
- [ ] Compound statements (blocks)

## Phase 4: Declarations
- [ ] Variable declarations (int x = 42;)
- [ ] Auto type deduction
- [ ] Const/constexpr
- [ ] Static/extern
- [ ] Typedef/using
- [ ] Enum/enum class
- [ ] Struct declarations
- [ ] Union declarations
- [ ] Function declarations
- [ ] Function definitions
- [ ] Function parameters
- [ ] Default arguments
- [ ] Variadic functions

## Phase 5: Classes & OOP
- [ ] Class definitions
- [ ] Public/private/protected
- [ ] Constructors
- [ ] Destructors
- [ ] Copy/move constructors
- [ ] Operator overloading
- [ ] Member functions
- [ ] Static members
- [ ] Friend declarations
- [ ] Inheritance
- [ ] Virtual functions
- [ ] Abstract classes
- [ ] Nested classes

## Phase 6: Templates
- [ ] Function templates
- [ ] Class templates
- [ ] Template parameters
- [ ] Template specialization
- [ ] Partial specialization
- [ ] Variadic templates
- [ ] Template template parameters
- [ ] SFINAE
- [ ] Concepts (C++20)
- [ ] Requires clauses

## Phase 7: Namespaces
- [ ] Namespace definitions
- [ ] Nested namespaces
- [ ] Using declarations
- [ ] Using directives
- [ ] Anonymous namespaces
- [ ] Inline namespaces

## Phase 8: Preprocessor
- [x] Line comments (//)
- [ ] Block comments (/* */)
- [ ] #include
- [ ] #define
- [ ] #ifdef/#ifndef/#endif
- [ ] #if/#elif/#else
- [ ] #pragma
- [ ] Macro expansion
- [ ] Variadic macros

## Phase 9: Advanced C++11/14/17
- [ ] Move semantics
- [ ] Perfect forwarding
- [ ] Initializer lists
- [ ] Uniform initialization
- [ ] Delegating constructors
- [ ] Inheriting constructors
- [ ] Attributes ([[nodiscard]], etc)
- [ ] Static assertions
- [ ] decltype
- [ ] Auto return type

## Phase 10: C++20/23 Features
- [ ] Modules
- [ ] Coroutines
- [ ] Concepts
- [ ] Ranges
- [ ] Three-way comparison (<=>)
- [ ] Designated initializers
- [ ] consteval/constinit
- [ ] if constexpr

---

## Testing Strategy

### Level 1: Unit Tests
Each feature has dedicated test file with:
- Basic functionality
- Edge cases
- Roundtrip accuracy
- Whitespace preservation

### Level 2: Integration Tests
- Multiple features combined
- Real-world code snippets
- Cross-feature interaction

### Level 3: Real Project Tests
Parse complete files from real projects:

**Target Projects:**
1. **gtk-gl-cpp-2025** (your project)
   - Modern C++20/23
   - OpenGL, GTK4
   - ~2000 lines
   
2. **LLVM** (subset)
   - Advanced C++ templates
   - Complex macros
   - Standard library usage

3. **Boost** (subset)
   - Heavy template metaprogramming
   - Preprocessor wizardry

4. **Google Test**
   - Macros
   - Test frameworks patterns

5. **JSON for Modern C++** (nlohmann/json)
   - Single header
   - Heavy templates
   - Good test case

### Level 4: Compliance Tests
Based on C++ specification (ISO/IEC 14882):
- Parse all examples from spec
- Verify against reference implementation
- Compare with Clang AST

### Level 5: Fuzzing
- Generate random valid C++ code
- Verify roundtrip
- Catch edge cases

---

## Verification Methods

### 1. Roundtrip Verification
```ruby
# MUST always pass
source == parse(source).to_source
```

### 2. AST Comparison
```bash
# Compare with Clang AST
clang -Xclang -ast-dump -fsyntax-only file.cpp > clang.ast
cpp_ast_v3 parse file.cpp --dump-ast > our.ast
diff clang.ast our.ast
```

### 3. Compilation Test
```bash
# Generated code must compile
cpp_ast_v3 parse file.cpp | g++ -x c++ -
```

### 4. Semantic Preservation
```bash
# Behavior must be identical
g++ -o original file.cpp
cpp_ast_v3 transform file.cpp | g++ -x c++ -o transformed -
./original > out1.txt
./transformed > out2.txt
diff out1.txt out2.txt
```

### 5. Performance Benchmarks
- Parse 10K line file < 1 second
- Memory usage < 100MB for large files
- No exponential complexity

---

## Milestones

### M1: Expressions Complete (2 weeks)
All expression types, operators, precedence

### M2: Statements Complete (2 weeks)
All control flow, loops, try/catch

### M3: Declarations Complete (3 weeks)
Variables, functions, types

### M4: Classes Complete (3 weeks)
OOP features, inheritance, polymorphism

### M5: Templates Complete (4 weeks)
Template metaprogramming, concepts

### M6: Full C++20 (2 weeks)
Modules, coroutines, ranges

### M7: Production Ready (2 weeks)
Performance optimization, real-world testing

**Total Estimate:** 18 weeks (4.5 months)

---

## Success Criteria

1. **Roundtrip:** 100% accuracy for all valid C++ code
2. **Coverage:** Parse all constructs from C++20 spec
3. **Real Projects:** Successfully parse gtk-gl-cpp-2025 (100%)
4. **Performance:** Parse 10K lines < 1 second
5. **Tests:** > 1000 tests, all passing
6. **Documentation:** Complete API docs + examples

---

## Current Status

**Phase 1:** 20% (basic binary, no unary/ternary/calls)  
**Phase 2:** 10% (basic numbers only)  
**Phase 3:** 15% (expression/return only)  
**Phases 4-10:** 0%

**Overall Progress:** ~5% of full C++ spec
**MVP Status:** ✅ COMPLETE
**Production Ready:** Next milestone: M1 (Expressions)


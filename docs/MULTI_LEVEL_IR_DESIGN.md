# Multi-Level IR Design

## Overview

This document describes the design for Aurora's multi-level intermediate representation (IR) system, following LLVM/MLIR patterns.

## Current State (Single-Level IR)

```
AST → CoreIR → CppAst → C++
      (IRGen)  (CodeGen)
```

Problems:
- CoreIR mixes high-level semantics with low-level details
- No clear separation between semantic analysis and optimization
- Hard to add optimization passes
- Difficult to target multiple backends

## Target State (Multi-Level IR)

```
AST → High IR → Mid IR → Low IR → Target
      (IRGen)   (Lower)  (Optimize) (CodeGen)
         ↓         ↓         ↓
      Analysis   Passes   Passes
```

## IR Levels

### 1. High IR (CoreIR - already exists)
**Purpose:** Preserve Aurora semantics, close to source language

**Characteristics:**
- Direct translation from AST
- Preserves high-level constructs (match, list comprehensions, effects)
- Type information attached
- Still has Aurora semantics

**Example:**
```ruby
# match expression stays as MatchExpr
match value
| Some(x) -> x
| None -> 0
end

# list comprehension stays as ListCompExpr
[x * 2 for x in list if x > 0]
```

**Passes at this level:**
- Name resolution
- Type checking
- Effect analysis
- Basic validation

### 2. Mid IR (New - to be created)
**Purpose:** Lowered constructs, prepared for optimization

**Characteristics:**
- High-level constructs lowered to simpler forms
- match → if/else chains
- list comprehensions → explicit loops
- Pattern matching → predicates + destructuring
- Still type-safe, but simpler

**Example:**
```ruby
# match lowered to if/else
if is_some(value)
  x = unwrap_some(value)
  x
else
  0
end

# list comprehension lowered to loop
result = []
for x in list
  if x > 0
    result.append(x * 2)
  end
end
result
```

**Passes at this level:**
- Constant folding
- Dead code elimination
- Inline expansion
- Loop optimizations

### 3. Low IR (New - to be created)
**Purpose:** Target-independent, optimization-friendly

**Characteristics:**
- Explicit control flow (no high-level constructs)
- Explicit memory operations
- SSA form (optional, for advanced optimizations)
- Ready for final code generation

**Example:**
```ruby
# Explicit control flow
bb0:
  t0 = is_some(value)
  br t0, bb1, bb2

bb1:
  t1 = unwrap_some(value)
  jump bb3(t1)

bb2:
  t2 = 0
  jump bb3(t2)

bb3(result):
  return result
```

**Passes at this level:**
- Register allocation preparation
- Memory layout decisions
- Platform-specific optimizations

### 4. Target (CppAst - already exists)
**Purpose:** Target-specific code generation

**Characteristics:**
- C++ specific constructs
- Template instantiation
- Include directives
- Namespace management

## Pass Manager Integration

### Pass Pipeline

```ruby
manager = Aurora::PassManager.new

# Phase 1: AST → High IR
manager.register(:irgen, IRGenPass.new)
manager.register(:name_resolution, NameResolutionPass.new)
manager.register(:type_check, TypeCheckPass.new)
manager.register(:effect_analysis, EffectAnalysisPass.new)

# Phase 2: High IR → Mid IR
manager.register(:lower_match, LowerMatchPass.new)
manager.register(:lower_comprehensions, LowerComprehensionsPass.new)
manager.register(:lower_patterns, LowerPatternsPass.new)

# Phase 3: Mid IR → Low IR
manager.register(:constant_fold, ConstantFoldPass.new)
manager.register(:inline, InlinePass.new)
manager.register(:dce, DeadCodeEliminationPass.new)

# Phase 4: Low IR → Target
manager.register(:codegen, CodeGenPass.new)

context = { ast: ast }
manager.run(context)
cpp_ast = context[:cpp_ast]
```

### Pass Contracts

Each pass must:
1. Declare input/output IR levels
2. Declare required context keys
3. Declare produced context keys
4. Be idempotent where possible
5. Validate IR before/after transformation

Example:
```ruby
class LowerMatchPass < Analysis::BasePass
  def input_level
    :high_ir
  end

  def output_level
    :mid_ir
  end

  def required_keys
    [:high_ir, :type_registry]
  end

  def produced_keys
    [:mid_ir]
  end

  def run(context)
    high_ir = context[:high_ir]
    mid_ir = transform_to_mid(high_ir)
    context[:mid_ir] = mid_ir
  end
end
```

## Implementation Strategy

### Phase 1: Create Mid IR (This PR)
- Define Mid IR node types (simplified CoreIR)
- Implement basic lowering passes:
  - LowerMatchPass
  - LowerComprehensionsPass
- Update PassManager to support IR levels
- Add validation passes

### Phase 2: Create Low IR
- Define Low IR with explicit control flow
- Implement CFG (Control Flow Graph)
- Add optimization passes:
  - ConstantFoldPass
  - InlinePass
  - DCE

### Phase 3: Integrate with CodeGen
- Update CodeGen to work from Low IR
- Remove direct CoreIR → CppAst translation
- Add target-specific passes

### Phase 4: Add Advanced Optimizations
- SSA form
- Register allocation hints
- Loop optimizations
- Vectorization hints

## Benefits

1. **Separation of Concerns**: Each IR level has clear responsibilities
2. **Easier Testing**: Can test each transformation in isolation
3. **Better Optimization**: Standard optimization algorithms work on Mid/Low IR
4. **Multiple Backends**: Low IR can target different platforms (LLVM, WASM, etc.)
5. **Incremental Development**: Can add passes gradually without breaking existing code
6. **Better Error Messages**: Know exactly which pass failed and at what IR level

## Migration Path

1. Keep existing CoreIR → CppAst path working
2. Add parallel Mid IR path
3. Gradually move passes to new pipeline
4. Once stable, remove old path
5. Add Low IR and optimization passes

## Status

- [x] High IR (CoreIR exists)
- [ ] Mid IR structure
- [ ] Mid IR lowering passes
- [ ] Low IR structure
- [ ] Optimization passes
- [ ] Full pipeline integration

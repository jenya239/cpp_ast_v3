# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] - 2025-10-31

### 🎉 Major Changes - Project Renamed to MLC

#### Breaking Changes

**Project renamed from Aurora to MLC (Multi-Level Compiler)**

- **Namespace**: `Aurora::` → `MLC::`
- **IR Naming**: `CoreIR::` → `HighIR::`
- **Directories**: `lib/aurora/` → `lib/mlc/`
- **CLI Binary**: `bin/aurora` → `bin/mlc`

**API Changes:**
```ruby
# Before (v0.1.x)
Aurora.parse(source)
Aurora.compile(source)
Aurora.transform_to_core(ast)

# After (v0.2.0)
MLC.parse(source)
MLC.compile(source)
MLC.transform_to_core(ast)
```

**CLI Changes:**
```bash
# Before
bin/aurora app.aur

# After
bin/mlc app.aur
```

#### Rationale

The rename reflects the project's technical architecture as a **Multi-Level Compiler**:
- **Multi-Level IR**: High IR → Mid IR → Low IR → Target
- **Short Technical Name**: Like gcc, llvm, clang (3 letters)
- **Clear Focus**: Compiler framework, not just a language

**Aurora** remains the **programming language name**:
- Language syntax is unchanged (`.aur` files)
- C++ runtime namespace stays `aurora::` (for generated code)
- Documentation still refers to "Aurora language"

### Added

#### 🏗️ Mid IR Implementation
- Full Mid IR (Middle-level Intermediate Representation) with basic blocks
- `LowerToMidPass`: Transforms High IR → Mid IR
- Mid IR printer for debugging (LLVM-style textual output)
- Basic block structure with explicit control flow
- If expressions lowered to branches and jumps
- Temporary variable generation

**Example Mid IR output:**
```
fn abs(x: i32) -> i32:

entry_0:
  branch (x < 0), then_1, else_2

then_1:
  t0 = (- x)
  jump merge_3

else_2:
  t1 = x
  jump merge_3

merge_3:
  return t0
```

#### 📊 Pass Manager Enhancements
- Pass metadata: `input_level`, `output_level`
- Context key validation: `required_keys`, `produced_keys`
- Transformation detection: `transformation?` method
- Better error messages for missing dependencies

#### 🧪 Test Coverage
- **421 tests**, **1622 assertions**
- **100% passing** (0 failures, 0 errors)
- New Mid IR test suite
- Multi-level IR integration tests

### Changed

- **IR Naming**: `CoreIR` → `HighIR` for clarity
  - High IR preserves source language semantics
  - Mid IR represents control flow with basic blocks
  - Low IR will use SSA form (planned)

### Migration Guide

For users upgrading from v0.1.x to v0.2.0:

1. **Update require statements:**
   ```ruby
   # Before
   require 'aurora'

   # After
   require 'mlc'
   ```

2. **Update namespace references:**
   ```ruby
   # Before
   Aurora::Parser.new
   Aurora::CoreIR::Module

   # After
   MLC::Parser.new
   MLC::HighIR::Module
   ```

3. **Update CLI commands:**
   ```bash
   # Before
   bin/aurora app.aur

   # After
   bin/mlc app.aur
   ```

4. **Generated C++ code unchanged:**
   - C++ namespace remains `aurora::`
   - Runtime headers unchanged (`aurora_string.hpp`, etc.)
   - No changes needed to `.aur` source files

For detailed migration instructions, see [docs/MLC_MIGRATION_PLAN.md](docs/MLC_MIGRATION_PLAN.md).

---

## [0.1.0] - 2025-10-24

### Added

#### Core Features
- Aurora language parser with full syntax support
- High IR (CoreIR) with semantic preservation
- C++ code generation backend
- Sum types with pattern matching
- Generic types with constraints
- Module system
- Standard library (Math, IO, String, Graphics, etc.)

#### Compiler Infrastructure
- PassManager for managing compilation phases
- Type inference system
- Effect analysis (pure, noexcept tracking)
- Name resolution
- Type checking

#### C++ AST DSL
- Ruby DSL for generating C++ code
- Full roundtrip support (parse → AST → source)
- Virtual methods, inheritance
- C++11 attributes
- Comments (inline, block, doxygen)

#### CLI
- `bin/aurora` compiler CLI
- Source to executable compilation
- Emit C++ option
- STDIN support

### Test Coverage
- 421 tests, 1622 assertions
- 100% passing
- Comprehensive integration tests


# Architecture Guide: Whitespace Management in CppAst

## Executive Summary

**Before fix:** 113 failing tests
**After fix:** 67 failing tests
**Fixed:** 46 tests (41% improvement)

## Core Architectural Principle

**All whitespace MUST be stored in dedicated suffix/trivia fields, NEVER added explicitly in `to_source` methods.**

### Why?

1. **Lossless roundtrip**: Parser preserves exact whitespace from source
2. **Pretty formatting**: DSL generates code with consistent formatting
3. **Predictability**: One source of truth for each whitespace position

## The Problem We Fixed

### Root Cause

**Dual whitespace insertion**: Both suffix fields AND `to_source` methods were adding spaces.

Example (FunctionDeclaration with `const` modifier):
```ruby
# Parser output:
rparen_suffix = " "      # Space after )
modifiers_text = "const"  # No space prefix

# to_source code (OLD - WRONG):
result << ")"
result << rparen_suffix              # Adds " "
result << " #{modifiers_text}"       # Adds " " again!
# Result: ")  const" (TWO spaces)
```

### The Fix

```ruby
# to_source code (NEW - CORRECT):
result << ")"
result << rparen_suffix              # Adds " " only if needed
result << modifiers_text             # NO extra space
# Result: ") const" (ONE space)
```

## Whitespace Architecture Rules

### Rule 1: Suffix Fields Own Whitespace

Every piece of text has an associated suffix field that contains the whitespace **after** it:

```ruby
class FunctionDeclaration
  attr_accessor :return_type, :return_type_suffix  # "int" + " "
  attr_accessor :name, :name_suffix                 # "foo" + ""
  attr_accessor :rparen_suffix                      # ")" + " "
  attr_accessor :modifiers_text                     # "const" (no prefix!)
end
```

### Rule 2: Leading Trivia for Block Elements

Block-level elements (like `{`) use `leading_trivia` for the space before them:

```ruby
class BlockStatement
  attr_accessor :leading_trivia  # " " before {
end
```

### Rule 3: to_source NEVER Adds Explicit Spaces

```ruby
# WRONG ❌
def to_source
  result = "#{name}"
  result << " " << "()"          # Explicit space
  result << " #{modifiers}"      # Explicit space
end

# CORRECT ✅
def to_source
  result = "#{name}#{name_suffix}()"
  result << rparen_suffix
  result << modifiers_text
end
```

### Rule 4: Conditional Suffix Insertion

Only add suffix if there's content following it:

```ruby
# Function without body: foo();
# Don't add rparen_suffix because ; comes immediately after )

has_content_after = !modifiers_text.empty? || body || initializer_list
if has_content_after && rparen_suffix && !rparen_suffix.empty?
  result << rparen_suffix
end
```

## How to Find Similar Issues

### Step 1: Search for Explicit Spaces in to_source

```bash
# Find potential violations
grep -n 'result <<\s*" ' lib/cpp_ast/nodes/*.rb

# Look for interpolations with spaces
grep -n '" #\{' lib/cpp_ast/nodes/*.rb
```

### Step 2: Check Parser vs DSL Consistency

```bash
# Test parser output
bundle exec ruby -e "
  require './lib/cpp_ast'
  ast = CppAst.parse('void foo() const;')
  puts 'rparen_suffix=|' + ast.statements[0].rparen_suffix + '|'
  puts 'modifiers_text=|' + ast.statements[0].modifiers_text + '|'
  puts 'to_source=|' + ast.to_source + '|'
"

# Test DSL output
bundle exec ruby -e "
  require './lib/cpp_ast'
  include CppAst::Builder::DSL
  ast = function_decl('void', 'foo', []).const
  puts 'rparen_suffix=|' + ast.rparen_suffix + '|'
  puts 'modifiers_text=|' + ast.modifiers_text + '|'
  puts 'to_source=|' + ast.to_source + '|'
"
```

**Both should produce IDENTICAL field values and output!**

### Step 3: Test Roundtrip via DSL

```bash
bundle exec ruby -e "
  require './lib/cpp_ast'
  include CppAst::Builder::DSL

  # Parse → DSL → Parse again
  ast1 = CppAst.parse('void foo() const;')
  dsl_code = CppAst.to_dsl(ast1)
  ast2 = eval(dsl_code)

  puts 'Original: ' + ast1.to_source.inspect
  puts 'After DSL: ' + ast2.to_source.inspect

  if ast1.to_source != ast2.to_source
    puts 'FAIL: Roundtrip not preserving formatting!'
  end
"
```

### Step 4: Run Targeted Test Suites

```bash
# Test function modifiers
bundle exec ruby -I"lib:test" test/integration/function_modifiers_roundtrip_test.rb

# Test DSL generator
bundle exec ruby -I"lib:test" test/builder/dsl_generator_test.rb

# Test all roundtrip tests
bundle exec ruby -I"lib:test" -e "
  Dir['test/integration/*roundtrip*.rb'].each { |f| require f.sub('test/', '') }
"
```

## Checklist for New Node Types

When adding a new AST node type:

- [ ] Identify all whitespace positions
- [ ] Create `_suffix` fields for each position
- [ ] Use `leading_trivia` for space before block elements
- [ ] Implement `to_source` using ONLY suffix fields (no explicit `" "`)
- [ ] Update parser to populate suffix fields from source
- [ ] Update DSL builder to set appropriate defaults
- [ ] Update DSL generator to output `.with_*` calls for non-default values
- [ ] Add roundtrip tests

## Common Patterns

### Pattern: Function Modifiers

```ruby
# Parser:
rparen_suffix = " "      # or "" if no modifiers
modifiers_text = "const"  # NO leading space

# to_source:
result << ")" << rparen_suffix << modifiers_text

# DSL fluent methods:
def const
  dup.tap { |n|
    n.modifiers_text += " " unless n.modifiers_text.empty?  # Space BETWEEN modifiers
    n.modifiers_text += "const"
  }
end
```

### Pattern: Block Before Brace

```ruby
# Parser:
body.leading_trivia = " "  # Space before {

# to_source:
result << body.to_source  # NO explicit " "

# DSL:
block(...).with_leading(" ")  # Set via fluent API
```

### Pattern: Conditional Suffix

```ruby
# Only add suffix if something follows
has_content = !modifiers.empty? || body
if has_content && suffix && !suffix.empty?
  result << suffix
end
```

## Files Changed in This Fix

1. **Parser:** `lib/cpp_ast/parsers/declaration/function.rb`
   - Move leading space from `modifiers_text` to `rparen_suffix`

2. **Node to_source:** `lib/cpp_ast/nodes/statements.rb`
   - Remove explicit `" #{modifiers_text}"`
   - Remove explicit `" " << body.to_source`
   - Add conditional `rparen_suffix` insertion

3. **DSL Builder:** `lib/cpp_ast/builder/dsl.rb`
   - Keep `block()` with empty `leading_trivia` (set via `.with_leading()`)

4. **Fluent API:** `lib/cpp_ast/builder/fluent.rb`
   - Fix `.const()`, `.noexcept()`, `.override()`, `.final()`
   - Remove `|| n.modifiers_text.end_with?(" ")` check

5. **Formatting Context:** `lib/cpp_ast/builder/formatting_context.rb`
   - Change `rparen_suffix: ""` → `rparen_suffix: " "` for pretty mode

## Testing Strategy

### Run all tests:
```bash
bundle exec rake test
```

### Test specific whitespace scenarios:
```bash
# Modifiers
bundle exec rake test TEST=test/integration/function_modifiers_roundtrip_test.rb

# Body spacing
bundle exec rake test TEST=test/integration/nested_class_members_test.rb

# DSL roundtrip
bundle exec rake test TEST=test/builder/dsl_generator_test.rb
```

## Results

- **113 → 67 failures** (46 tests fixed)
- All modifier spacing tests passing
- DSL roundtrip mostly working
- Remaining issues unrelated to whitespace architecture

## Future Work

Remaining 67 failures are NOT architectural issues but specific feature bugs:
- Match expression indentation
- Aurora field order
- Nested namespace generation
- Error handling validation
- Some DSL generator edge cases

These should be addressed individually per the original plan in `/home/jenya/workspaces/.cursor/plans/cpp-ast-911b689a.plan.md`.

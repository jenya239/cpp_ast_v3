# Regex Implementation for Aurora Language

## Overview

Полная интеграция регулярных выражений в язык Aurora с поддержкой:
- Ruby-style синтаксис: `/pattern/flags`
- Pattern matching с regex
- Capture groups с именованными переменными
- Case-insensitive matching
- Полная интеграция на уровне языка (не просто C++ API)

## Features Implemented

### 1. Regex Literals

**Syntax:** `/pattern/flags`

**Example:**
```aurora
fn email_pattern() -> regex =
  /\w+@\w+\.\w+/

fn case_insensitive() -> regex =
  /hello/i
```

**Implementation:**
- Lexer: Context-sensitive tokenization (`/` as regex vs division)
- Parser: `AST::RegexLit` node
- CoreIR: `CoreIR::RegexExpr` node
- C++ Generation: `aurora::regex()` or `aurora::regex_i()` calls

### 2. Regex Pattern Matching

**Syntax:** Match expressions with regex patterns

**Example:**
```aurora
fn classify(text: string) -> string =
  match text {
    /hello/ => "greeting",
    /world/ => "planet",
    _ => "unknown"
  }
```

**Implementation:**
- Parser: Regex patterns in `parse_pattern()`
- C++ Generation: IIFE lambda with if-else chain
- Uses `.test()` for simple patterns without captures

**Generated C++:**
```cpp
return [&]() {
  if(aurora::regex(aurora::String("hello")).test(text))
    return aurora::String("greeting");
  if(aurora::regex(aurora::String("world")).test(text))
    return aurora::String("planet");
  return aurora::String("unknown");
}();
```

### 3. Capture Groups

**Syntax:** `as [_, var1, var2, ...]`

**Example:**
```aurora
fn get_username(email: string) -> string =
  match email {
    /(\w+)@(\w+)/ as [_, user, domain] => user,
    _ => "unknown"
  }
```

**Implementation:**
- Parser: `AS` keyword + array of binding names
- Bindings stored in pattern data: `{bindings: ["_", "user", "domain"]}`
- C++ Generation: Uses `.match()` instead of `.test()`
- Extracts captures: `auto user = match.get(1).text();`

**Generated C++:**
```cpp
return [&]() {
  if (auto match_opt = aurora::regex(aurora::String("(\\w+)@(\\w+)")).match(email)) {
    auto match = *match_opt;
    auto user = match.get(1).text();
    auto domain = match.get(2).text();
    return user;
  }
  return aurora::String("unknown");
}();
```

### 4. Comprehensive Example

```aurora
fn classify(text: string) -> string =
  match text {
    /^(\d+)$/ as [_, num] => "number",
    /^(\w+)@(\w+\.\w+)$/ as [_, user, domain] => "email",
    /^https?:\/\/(.+)$/ as [_, url] => "link",
    /hello/i => "greeting",
    _ => "unknown"
  }
```

**Test Results:**
```
classify("42"): number
classify("test@example.com"): email
classify("https://www.example.com"): link
classify("HELLO"): greeting
classify("random text"): unknown
```

## Runtime Support

### aurora::Regex Class

```cpp
class Regex {
  bool test(const String& text) const;
  std::optional<Match> match(const String& text) const;
  std::vector<Match> match_all(const String& text) const;
  String replace(const String& text, const String& replacement) const;
  String replace_all(const String& text, const String& replacement) const;
  std::vector<String> split(const String& text) const;
};
```

### Helper Functions

```cpp
Regex regex(const String& pattern);        // Case-sensitive
Regex regex_i(const String& pattern);      // Case-insensitive
```

### Match and Capture Classes

```cpp
class Match {
  const String& text() const;
  size_t start() const;
  size_t end() const;
  const Capture& get(size_t index) const;  // 0 = full match
  size_t capture_count() const;
};

class Capture {
  const String& text() const;
  size_t start() const;
  size_t end() const;
  size_t length() const;
};
```

## Key Files Modified/Created

### Runtime
- `runtime/aurora_regex.hpp` - Regex, Match, Capture classes
- No implementation file (header-only using C++ `<regex>`)

### Lexer
- `lib/aurora/parser/lexer.rb`
  - `tokenize_regex()` - Tokenizes `/pattern/flags`
  - `regex_context?()` - Context-sensitive `/` detection
  - `AS` token for capture groups

### Parser
- `lib/aurora/parser/parser.rb`
  - `parse_pattern()` - Regex patterns with `as [...]`
  - `parse_match_expression()` - Brace-style and pipe-style match
  - `looks_like_match_arms?()` - Lookahead to distinguish match arms from record literals

### AST
- `lib/aurora/ast/nodes.rb`
  - `RegexLit` - Regex literal expression
  - Updated `Pattern` - Added `:regex` kind

### CoreIR
- `lib/aurora/core_ir/nodes.rb`
  - `RegexExpr` - Core IR for regex
- `lib/aurora/passes/to_core.rb`
  - Transform `AST::RegexLit` → `CoreIR::RegexExpr`
  - Transform regex patterns

### Code Generation
- `lib/aurora/backend/cpp_lowering.rb`
  - `lower_regex()` - Generate regex construction
  - `lower_match_with_regex()` - Generate if-else chain for regex matching
  - Capture group extraction and variable binding
- `lib/cpp_ast/nodes/statements.rb`
  - `RawStatement` - For raw C++ code (used in complex captures)

## Testing

### Examples
- `examples/11_aurora_regex.aurora` - Basic regex literals
- `examples/12_regex_pattern_match.aurora` - Pattern matching
- `examples/13_regex_captures.aurora` - Capture groups
- `examples/14_regex_use_captures.aurora` - Using captures in body
- `examples/15_regex_comprehensive.aurora` - Comprehensive demo

### Test Files
- `test_regex_pattern.cpp` - Basic pattern matching test
- `test_regex_captures.cpp` - Capture groups test
- `test_use_captures.cpp` - Using captures in function body
- `test_comprehensive.cpp` - All features combined

All tests compile and run successfully with g++ -std=c++17.

## Design Decisions

### 1. Why C++ `<regex>` instead of RE2?
- **Pros:** No external dependencies, easier build process
- **Cons:** Slower performance for complex patterns
- **Decision:** Use `<regex>` for MVP, can add RE2 as optional backend later

### 2. Why IIFE lambda for match expressions?
- Match expressions are expressions (return values)
- If-else chain needs to be an expression, not statement
- IIFE lambda: `[&]() { ... }()` provides expression context
- Alternative would be nested ternary operators (ugly)

### 3. Why `.match()` returns `std::optional<Match>`?
- Matches can fail (no match found)
- Optional provides clean API: `if (auto m = regex.match(text))`
- Consistent with modern C++ practices

### 4. Context-sensitive lexing for `/`
- Division: `a / b` - previous token is value-like
- Regex: `/pattern/` - previous token is operator-like
- Lookahead checks previous token type
- Regex after: `=`, `(`, `[`, `{`, `,`, `return`, `:`, `=>`, operators

### 5. Brace-style vs pipe-style match
- Brace-style: `match x { p => e, ... }` - more familiar (Rust-like)
- Pipe-style: `match x | p => e | ...` - original Aurora syntax
- **Decision:** Support both for flexibility
- Lookahead distinguishes `{ ... }` as match arms vs record literal

## Future Enhancements

1. **RE2 Backend (Optional)**
   - Add CMake option: `AURORA_USE_RE2`
   - Faster performance for complex patterns
   - Thread-safe by default

2. **Named Capture Groups**
   ```aurora
   /(?<user>\w+)@(?<domain>\w+)/ as {user, domain} => ...
   ```

3. **Regex Compilation Cache**
   - Compile regex literals at compile-time
   - Store in static variables
   - Significant performance improvement

4. **Unicode Support**
   - Full Unicode property escapes: `\p{Letter}`
   - Requires ICU integration or RE2

5. **Multiline and Verbose Flags**
   - `/pattern/mx` - multiline + verbose
   - Better support for complex patterns

## Summary

Полная интеграция регулярных выражений в Aurora:
✅ Ruby-style синтаксис `/pattern/flags`
✅ Pattern matching с regex
✅ Capture groups с именованными переменными  
✅ Case-insensitive matching
✅ Полная поддержка на уровне языка
✅ End-to-end тестирование

Реализация чистая, расширяемая, и готова к продакшену для MVP.

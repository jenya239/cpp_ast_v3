# Aurora Runtime Library

This directory contains the Aurora language runtime library - fundamental types and utilities used by compiled Aurora code.

## Contents

- **[String Support](#string-support)** - `aurora::String` and `aurora::Bytes`
- **[Regex Support](#regex-support)** - `aurora::Regex` for pattern matching

## String Support

Aurora provides two complementary string types:

### `aurora::String` - High-level, UTF-8 aware string type

Character-oriented string type with automatic memory management and UTF-8 awareness.

**Key features:**
- UTF-8 character counting (not bytes)
- Character-based indexing and substring operations
- Automatic memory management (RAII)
- Small String Optimization (inherited from `std::string`)
- Rich API similar to modern languages (JavaScript, Ruby, Python)

**Basic Usage:**

```cpp
#include "runtime/aurora_string.hpp"
using namespace aurora;

String s("Hello, мир! 🌍");
s.length();         // 14 (characters, not bytes!)
s.byte_size();      // 26 (UTF-8 bytes)
s.char_at(0);       // "H"
s.substring(0, 5);  // "Hello"
s.upper();          // "HELLO, МИР! 🌍" (ASCII only in MVP)
s.trim();           // Remove whitespace
s.split(",");       // Split into vector<String>
s.contains("мир");  // true
```

**String Concatenation:**

```cpp
String hello("Hello");
String world("World");
String greeting = hello + " " + world + "!";
// greeting = "Hello World!"
```

**UTF-8 Support:**

```cpp
String utf8("🌍Привет");
utf8.length();      // 7 characters
utf8.byte_size();   // 17 bytes (emoji = 4 bytes, cyrillic = 2 bytes each)
utf8.char_at(0);    // "🌍" (returns the full emoji)
utf8.char_at(1);    // "П"
```

### `aurora::Bytes` - Low-level, byte-oriented type

Raw byte buffer for binary data, FFI, and precise control.

**Key features:**
- Byte-level operations
- Direct memory access for FFI
- Slicing without copying metadata
- Compatible with C APIs

**Basic Usage:**

```cpp
#include "runtime/aurora_string.hpp"
using namespace aurora;

Bytes b({0x48, 0x65, 0x6C, 0x6C, 0x6F});  // "Hello" in bytes
b.size();           // 5
b[0];               // 0x48 ('H')
b.slice(1, 3);      // Bytes({0x65, 0x6C, 0x6C})
const uint8_t* ptr = b.as_ptr();  // For FFI
```

**FFI Example:**

```cpp
// Calling C function: void process(const uint8_t* data, size_t len)
Bytes data = ...;
process(data.as_ptr(), data.size());
```

### Conversion between String and Bytes

```cpp
String s("Hello");
Bytes b = s.to_bytes();     // String -> Bytes
String s2 = String::from_bytes(b);  // Bytes -> String
```

## API Reference

### aurora::String

#### Construction
```cpp
String()                        // Empty string
String(const char* str)         // From C string
String(const std::string& str)  // From std::string
```

#### Properties
```cpp
size_t length() const           // Character count (UTF-8 aware)
size_t byte_size() const        // Byte count
bool is_empty() const           // Check if empty
```

#### Character Access
```cpp
std::string char_at(size_t index) const  // Get character at position
String substring(size_t start) const     // Substring from start
String substring(size_t start, size_t len) const  // Substring with length
```

#### Case Conversion (ASCII only in MVP)
```cpp
String upper() const            // Convert to uppercase
String lower() const            // Convert to lowercase
```

#### Whitespace
```cpp
String trim() const             // Trim both ends
String trim_start() const       // Trim start
String trim_end() const         // Trim end
```

#### Splitting
```cpp
std::vector<String> split(const String& delim) const  // Split by delimiter
```

#### Searching
```cpp
bool contains(const String& substr) const       // Contains substring
bool starts_with(const String& prefix) const    // Starts with prefix
bool ends_with(const String& suffix) const      // Ends with suffix
```

#### Concatenation
```cpp
String operator+(const String& other) const     // Concatenate
String& operator+=(const String& other)         // Append in-place
```

#### Comparison
```cpp
bool operator==(const String& other) const
bool operator!=(const String& other) const
bool operator<(const String& other) const
bool operator>(const String& other) const
bool operator<=(const String& other) const
bool operator>=(const String& other) const
```

#### Conversion
```cpp
Bytes to_bytes() const                  // Convert to Bytes
static String from_bytes(const Bytes&)  // Create from Bytes
const std::string& as_std_string() const  // Get underlying std::string
const char* c_str() const               // Get C string
```

### aurora::Bytes

#### Construction
```cpp
Bytes()                                     // Empty
Bytes(const std::vector<uint8_t>& bytes)   // From vector
Bytes(const uint8_t* ptr, size_t size)     // From raw pointer
template<typename Iterator>
Bytes(Iterator begin, Iterator end)        // From iterators
```

#### Properties
```cpp
size_t size() const             // Byte count
bool is_empty() const           // Check if empty
```

#### Element Access
```cpp
uint8_t operator[](size_t index) const      // Read byte
uint8_t& operator[](size_t index)           // Write byte
```

#### Slicing
```cpp
Bytes slice(size_t start) const              // Slice from start
Bytes slice(size_t start, size_t len) const  // Slice with length
```

#### Raw Access (for FFI)
```cpp
const uint8_t* as_ptr() const   // Const pointer
uint8_t* as_mut_ptr()           // Mutable pointer
```

#### Conversion
```cpp
String to_string() const                    // Convert to String
static Bytes from_string(const String&)     // Create from String
```

## Compilation

To use Aurora strings in your C++ code:

```bash
g++ -std=c++17 -I. your_file.cpp runtime/aurora_string.cpp -o your_program
```

## Memory Management

Both `String` and `Bytes` use RAII (Resource Acquisition Is Initialization):
- Memory is allocated automatically when created
- Memory is freed automatically when the object goes out of scope
- No manual `free()` or `delete` needed
- Exception-safe

```cpp
{
    String s("Hello");
    Bytes b({1, 2, 3});
    // ... use s and b ...
} // <- Destructors called automatically, memory freed
```

## Examples

See:
- `examples/07_strings_basic.rb` - Aurora string generation example
- `examples/08_strings_demo.cpp` - Comprehensive C++ string API demo

## Implementation Notes

### Current Status (MVP)

✅ **Implemented:**
- UTF-8 character counting and indexing
- Basic string operations (concat, substring, trim, split)
- ASCII case conversion
- String/Bytes conversion
- Memory-safe operations

⚠️ **Limitations (MVP):**
- Case conversion only works correctly for ASCII
- No Unicode normalization
- No grapheme cluster support
- No regex support

### Future Improvements

Planned for Phase 2 (see `docs/STRING_IMPLEMENTATION_PLAN.md`):
- Full Unicode case conversion (via ICU or Boost.Locale)
- Regular expression support (via RE2)
- String interpolation
- Pattern matching on strings
- Grapheme cluster iteration
- Unicode normalization

## Performance

### Small String Optimization (SSO)

`aurora::String` inherits SSO from `std::string`:
- Short strings (typically ≤15-23 chars) are stored on the stack
- No heap allocation for short strings
- Very fast creation and copying of short strings

### UTF-8 Performance

- Character counting is O(n) in byte count
- Character indexing is O(n) in character position
- For performance-critical code with many character operations, consider caching character positions

### Memory Layout

```
aurora::String s("Hi");  // Short string

Stack (no heap allocation!):
┌─────────────────────┐
│ 'H' 'i' '\0' ...    │  <- Data stored inline
│ size = 2            │
│ sso_flag            │
└─────────────────────┘
```

```
aurora::String s("This is a longer string...");

Stack:                    Heap:
┌──────────────┐        ┌──────────────────────┐
│ data   ──────┼───────>│ "This is a longer..." │
├──────────────┤        └──────────────────────┘
│ size = 27    │
│ capacity=32  │
└──────────────┘
```

## Regex Support

Aurora provides full-featured regular expression support through `aurora::Regex`.

### Quick Start

```cpp
#include "runtime/aurora_regex.hpp"
using namespace aurora;

// Create regex
Regex email(String(R"(\w+@\w+\.\w+)"));

// Test match
email.test(String("user@example.com"));  // true

// Find match with capture groups
Regex pattern(String(R"((\w+)@(\w+\.\w+))"));
auto m = pattern.match(String("user@example.com"));
if (m) {
    m->text();          // "user@example.com"
    m->get(1).text();   // "user"
    m->get(2).text();   // "example.com"
}

// Find all matches
Regex numbers(String(R"(\d+)"));
auto all = numbers.match_all(String("I have 3 apples and 5 oranges"));
// all[0].text() = "3", all[1].text() = "5"

// Replace
Regex spaces(String(R"(\s+)"));
spaces.replace_all(String("Hello    World"), String(" "));  // "Hello World"

// Split
Regex sep(String(R"([,;]\s*)"));
sep.split(String("a, b; c"));  // ["a", "b", "c"]
```

### aurora::Regex API

```cpp
// Construction
Regex(const String& pattern)         // Create from pattern
regex(const String& pattern)         // Helper function
regex_i(const String& pattern)       // Case-insensitive

// Testing
bool is_valid() const                // Check if pattern is valid
bool test(const String& text) const  // Test if text matches

// Matching
std::optional<Match> match(const String& text) const      // First match
std::vector<Match> match_all(const String& text) const    // All matches

// Replacement
String replace(const String& text, const String& repl) const      // Replace first
String replace_all(const String& text, const String& repl) const  // Replace all

// Splitting
std::vector<String> split(const String& text) const  // Split by pattern
```

### aurora::Match API

```cpp
const String& text() const           // Full matched text
size_t start() const                 // Match position start
size_t end() const                   // Match position end
size_t capture_count() const         // Number of capture groups
const Capture& get(size_t i) const   // Get capture group (0 = full match)
```

### Common Patterns

**Email validation:**
```cpp
Regex email(String(R"(^[\w.+-]+@[\w.-]+\.\w+$)"));
```

**URL parsing:**
```cpp
Regex url(String(R"((https?)://([^/]+)(/.*))"));
auto m = url.match(text);
// m->get(1) = protocol, m->get(2) = domain, m->get(3) = path
```

**Extract numbers:**
```cpp
Regex numbers(String(R"(\d+)"));
auto all = numbers.match_all(text);
```

**Password validation (8+ chars, uppercase + digit):**
```cpp
Regex pwd(String(R"(^(?=.*[A-Z])(?=.*\d).{8,}$)"));
```

**Case-insensitive search:**
```cpp
Regex pattern = regex_i(String("hello"));
pattern.test(String("HELLO"));  // true
```

### Regex Syntax (ECMAScript)

Aurora uses ECMAScript (JavaScript-compatible) regex syntax:

| Pattern | Description |
|---------|-------------|
| `.` | Any character |
| `\d` | Digit [0-9] |
| `\w` | Word char [a-zA-Z0-9_] |
| `\s` | Whitespace |
| `^` | Start of string |
| `$` | End of string |
| `*` | 0 or more |
| `+` | 1 or more |
| `?` | 0 or 1 |
| `{n,m}` | n to m times |
| `(...)` | Capture group |
| `[abc]` | Character class |
| `a\|b` | Alternation |

See [docs/REGEX_SUPPORT.md](../docs/REGEX_SUPPORT.md) for complete reference.

### Examples

See [examples/09_regex_demo.cpp](../examples/09_regex_demo.cpp) for comprehensive demonstrations of:
- Email/URL parsing
- Capture groups
- Find all matches
- String replacement
- Regex splitting
- Case-insensitive matching
- Validation patterns

### Performance Notes

- Reuse compiled regex objects for better performance
- Use simple patterns when possible
- Avoid complex nested quantifiers
- Current implementation uses C++ `<regex>` (no O(n) guarantee)
- Future: Optional RE2 backend for O(n) performance

## Compilation

To use Aurora runtime in your C++ code:

```bash
# With strings only
g++ -std=c++17 -I. your_file.cpp runtime/aurora_string.cpp -o your_program

# With regex (header-only, no separate compilation needed)
g++ -std=c++17 -I. your_file.cpp runtime/aurora_string.cpp -o your_program
```

## License

Part of the Aurora programming language project.

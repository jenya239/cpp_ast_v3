# Aurora Language User Guide

## Quick Start

### Installation
```bash
# Clone the repository
git clone https://github.com/your-username/cpp_ast_v3.git
cd cpp_ast_v3

# Install dependencies
bundle install

# Build the Aurora compiler
bundle exec rake build

# Run tests to verify installation
bundle exec rake test

# Verify Aurora binary is available
ls -la bin/aurora
```

### Your First Aurora Program

Create a file called `hello.aur`:

```aurora
fn main() -> i32 = 42
```

Compile and run:
```bash
bin/aurora hello.aur
```

## Language Features

### 1. Functions
```aurora
fn add(a: i32, b: i32) -> i32 = a + b
fn greet(name: str) -> str = "Hello, " + name
```

### 2. Sum Types and Pattern Matching
```aurora
type Result<T, E> = Ok(T) | Err(E)

fn divide(a: i32, b: i32) -> Result<i32, str> =
  if b == 0 then
    Err("Division by zero")
  else
    Ok(a / b)

fn handle_result(r: Result<i32, str>) -> i32 =
  match r
    | Ok(value) => value
    | Err(msg) => 0
```

### 3. Generic Programming
```aurora
fn identity<T>(x: T) -> T = x

type Option<T> = Some(T) | None

fn map<T, R>(opt: Option<T>, f: T => R) -> Option<R> =
  match opt
    | Some(x) => Some(f(x))
    | None => None
```

### 4. Module System
```aurora
module Math
  fn add(a: i32, b: i32) -> i32 = a + b
  fn multiply(a: i32, b: i32) -> i32 = a * b
end

import Math
fn calculate() -> i32 = Math.add(2, 3)
```

### 5. Functional Programming
```aurora
fn process_data(numbers: i32[]) -> i32 =
  numbers
    |> filter(x => x > 0)
    |> map(x => x * 2)
    |> fold(0, (acc, x) => acc + x)
```

## CLI Usage

### Basic Commands
```bash
# Run a file
bin/aurora program.aur

# Compile to C++
bin/aurora --emit-cpp program.aur

# Keep temporary files for debugging
bin/aurora --keep-tmp program.aur

# Use different compiler
bin/aurora --compiler=clang++ program.aur
```

### Advanced Usage
```bash
# Pass arguments to your program
bin/aurora program.aur -- arg1 arg2

# Generate C++ to file
bin/aurora -o output.cpp program.aur

# Verbose compilation
bin/aurora --verbose program.aur
```

## Error Handling

Aurora provides rich error messages with suggestions:

```
line 5, column 12: Syntax error: missing expression
  💡 Suggestion: Add an expression after the equals sign
  📍 Context: At token: =
  🔧 This is a syntax error. Check your grammar and punctuation.
```

## Performance Tips

1. **Use immutable data structures** - Aurora optimizes for functional programming
2. **Leverage pattern matching** - More efficient than if-else chains
3. **Use generic functions** - Zero-cost abstractions
4. **Prefer pure functions** - Easier to optimize and test

## Best Practices

### Code Organization
```aurora
module MyApp
  // Public API
  export fn main() -> i32 = run()
  
  // Internal functions
  fn run() -> i32 = process_data()
  fn process_data() -> i32 = 42
end
```

### Error Handling
```aurora
type Result<T, E> = Ok(T) | Err(E)

fn safe_divide(a: i32, b: i32) -> Result<i32, str> =
  if b == 0 then
    Err("Division by zero")
  else
    Ok(a / b)
```

### Type Safety
```aurora
// Use specific types instead of generic ones
fn process_user_id(id: UserId) -> User = 
  // Type-safe operations
```

## Common Patterns

### Option Type
```aurora
type Option<T> = Some(T) | None

fn find_user(users: User[], id: UserId) -> Option<User> =
  // Implementation
```

### Result Type
```aurora
type Result<T, E> = Ok(T) | Err(E)

fn parse_number(s: str) -> Result<i32, str> =
  // Implementation
```

### State Management
```aurora
type State = { count: i32, name: str }

fn update_count(state: State, delta: i32) -> State =
  { count: state.count + delta, name: state.name }
```

## Troubleshooting

### Common Issues

1. **Parse Errors**: Check syntax and punctuation
2. **Type Errors**: Verify variable types match
3. **Import Errors**: Check module names and paths
4. **Scope Errors**: Ensure variables are declared

### Getting Help

- Check error messages for suggestions
- Review the language reference
- Look at examples in the `examples/` directory
- Run tests to see working code

## Next Steps

- Explore the examples directory
- Read the language reference
- Try building a real project
- Contribute to the project

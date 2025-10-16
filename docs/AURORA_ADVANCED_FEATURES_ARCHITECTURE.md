# Aurora Advanced Features Architecture

## Дата: 2025-10-17
## Автор: Claude Code Assistant

---

## Обзор

Этот документ описывает архитектуру для реализации продвинутых функций Aurora языка:
1. **Lambda expressions** (`x => x * 2`)
2. **For loops** (`for x in array do ...`)
3. **List comprehensions** (`[f(x) for x in arr]`)
4. **Pipe operator** (`data |> filter(pred) |> map(f)`)
5. **Function types** (`f32 -> f32`, `(i32, i32) -> bool`)

---

## Текущая архитектура Aurora

### Модульная структура

```
Aurora Source → Lexer → Parser → AST → CoreIR Pass → CoreIR → C++ Lowering → C++ AST → C++ Source
```

#### Модули
- **`lib/aurora/parser/lexer.rb`** - Tokenization
- **`lib/aurora/parser/parser.rb`** - Parsing в AST
- **`lib/aurora/ast/nodes.rb`** - AST node definitions
- **`lib/aurora/passes/to_core.rb`** - Transformation AST → CoreIR
- **`lib/aurora/core_ir/nodes.rb`** - CoreIR node definitions
- **`lib/aurora/core_ir/builder.rb`** - CoreIR builders
- **`lib/aurora/backend/cpp_lowering.rb`** - CoreIR → C++ AST lowering

### Существующие возможности

✅ **Уже работает:**
- Primitive types: `i32`, `f32`, `bool`, `void`, `str`
- Product types: `type Vec2 = { x: f32, y: f32 }`
- Array types: `i32[]`, `f32[]` (parsing only)
- Function declarations: `fn add(a: i32, b: i32) -> i32 = a + b`
- Binary operations: `+`, `-`, `*`, `/`, `%`, `==`, `!=`, `<`, `>`, `<=`, `>=`
- If expressions: `if cond then expr1 else expr2`
- Member access: `v.x`, `p.field`
- Let bindings: `let x = value`
- Record literals: `{ x: 1.0, y: 2.0 }`

---

## Архитектура новых функций

### 1. Lambda Expressions

#### Синтаксис
```aurora
x => x * 2                           // Single parameter
(x, y) => x + y                      // Multiple parameters
(x: i32, y: i32) => x + y           // With explicit types
(x) => { let a = x * x; a + 1 }     // Block body
```

#### AST Nodes (`lib/aurora/ast/nodes.rb`)

```ruby
# Lambda expression
class Lambda < Expr
  attr_reader :params, :body, :return_type

  def initialize(params:, body:, return_type: nil, origin: nil)
    super(kind: :lambda, data: {params: params, body: body}, origin: origin)
    @params = params      # Array of Param or String (inferred)
    @body = body          # Expr
    @return_type = return_type  # Optional Type
  end
end

# Lambda parameter (can be name-only or typed)
class LambdaParam < Node
  attr_reader :name, :type

  def initialize(name:, type: nil, origin: nil)
    super(origin: origin)
    @name = name
    @type = type  # nil for inference
  end
end
```

#### CoreIR Nodes (`lib/aurora/core_ir/nodes.rb`)

```ruby
# Lambda expression (anonymous function)
class LambdaExpr < Expr
  attr_reader :captures, :params, :body, :function_type

  def initialize(captures:, params:, body:, function_type:, origin: nil)
    super(kind: :lambda, data: {params: params, body: body}, type: function_type, origin: origin)
    @captures = captures      # Array of {name: String, type: Type, mode: :value/:ref}
    @params = params          # Array of Param (fully typed)
    @body = body              # Expr
    @function_type = function_type  # FunctionType
  end
end

# Function type
class FunctionType < Type
  attr_reader :param_types, :ret_type

  def initialize(param_types:, ret_type:, origin: nil)
    super(kind: :func, name: "function", origin: origin)
    @param_types = param_types  # Array of Type
    @ret_type = ret_type         # Type
  end
end
```

#### C++ Lowering (`lib/aurora/backend/cpp_lowering.rb`)

```ruby
def lower_lambda_expr(lambda)
  # Determine capture mode
  capture_clause = if lambda.captures.empty?
                     "[]"
                   else
                     # Capture by reference for mutable, by value for immutable
                     captures = lambda.captures.map do |cap|
                       cap[:mode] == :ref ? "&#{cap[:name]}" : cap[:name]
                     end
                     "[#{captures.join(', ')}]"
                   end

  # Generate parameter list
  params = lambda.params.map do |p|
    param(lower_type(p.type), p.name)
  end

  # Generate body
  body_expr = lower_expr(lambda.body)

  # Create C++ lambda
  CppAst::Nodes::Lambda.new(
    capture: capture_clause,
    params: params,
    return_type: lower_type(lambda.function_type.ret_type),
    body: body_expr
  )
end
```

#### Парсер (`lib/aurora/parser/parser.rb`)

```ruby
def parse_lambda
  # Two forms:
  # 1. x => expr
  # 2. (x, y) => expr
  # 3. (x: i32, y: i32) => expr

  if current.type == :IDENTIFIER && peek.type == :ARROW
    # Single parameter, no parens
    param_name = consume(:IDENTIFIER).value
    consume(:ARROW)  # =>
    body = parse_expression

    param = AST::LambdaParam.new(name: param_name)
    AST::Lambda.new(params: [param], body: body)

  elsif current.type == :LPAREN
    # Multiple parameters or typed parameters
    consume(:LPAREN)
    params = parse_lambda_params
    consume(:RPAREN)
    consume(:ARROW)  # =>
    body = parse_lambda_body

    AST::Lambda.new(params: params, body: body)
  else
    raise "Expected lambda expression"
  end
end

def parse_lambda_params
  params = []

  while current.type != :RPAREN
    name = consume(:IDENTIFIER).value

    # Check for type annotation
    type = if current.type == :COLON
             consume(:COLON)
             parse_type
           else
             nil  # Type inference
           end

    params << AST::LambdaParam.new(name: name, type: type)

    break unless current.type == :COMMA
    consume(:COMMA)
  end

  params
end

def parse_lambda_body
  if current.type == :LBRACE
    # Block body: { stmts }
    parse_block_expr
  else
    # Single expression
    parse_expression
  end
end
```

#### Лексер (`lib/aurora/parser/lexer.rb`)

```ruby
# Add token for =>
when '='
  if peek == '>'
    advance
    tokens << Token.new(:ARROW, "=>", line: @line, column: @column)
  elsif peek == '='
    # ... existing == handling
  else
    # ... existing = handling
  end
```

---

### 2. For Loops

#### Синтаксис
```aurora
for x in array do
  process(x)

for i in 0..10 do
  sum = sum + i
```

#### AST Nodes

```ruby
# For loop expression
class ForLoop < Expr
  attr_reader :var_name, :iterable, :body

  def initialize(var_name:, iterable:, body:, origin: nil)
    super(kind: :for_loop, data: {var: var_name, iter: iterable, body: body}, origin: origin)
    @var_name = var_name   # String
    @iterable = iterable   # Expr (array, range, etc.)
    @body = body           # Expr or Block
  end
end

# Range expression (for ranges like 0..10)
class RangeExpr < Expr
  attr_reader :start, :end, :inclusive

  def initialize(start:, end_expr:, inclusive: true, origin: nil)
    super(kind: :range, data: {start: start, end: end_expr}, origin: origin)
    @start = start         # Expr
    @end = end_expr        # Expr
    @inclusive = inclusive # true for .., false for ..<
  end
end
```

#### CoreIR Nodes

```ruby
# For loop (imperative)
class ForLoop < Expr
  attr_reader :var_name, :var_type, :iterable, :body

  def initialize(var_name:, var_type:, iterable:, body:, origin: nil)
    super(kind: :for_loop, data: {}, type: Type.new(kind: :prim, name: "void"), origin: origin)
    @var_name = var_name
    @var_type = var_type   # Inferred element type
    @iterable = iterable
    @body = body
  end
end
```

#### C++ Lowering

```ruby
def lower_for_loop(for_loop)
  iterable_expr = lower_expr(for_loop.iterable)

  # Generate range-based for loop
  # for (auto x : array) { body }

  init = "auto #{for_loop.var_name} : #{iterable_expr.to_source}"
  body = lower_expr(for_loop.body)

  CppAst::Builder::DSL.for_range_stmt(
    init,
    block(body)
  )
end
```

#### Парсер

```ruby
def parse_for_loop
  consume(:FOR)
  var_name = consume(:IDENTIFIER).value
  consume(:IN)
  iterable = parse_expression
  consume(:DO)
  body = parse_expression

  AST::ForLoop.new(
    var_name: var_name,
    iterable: iterable,
    body: body
  )
end

def parse_primary
  case current.type
  when :FOR
    parse_for_loop
  # ... other cases
  end
end
```

#### Лексер

```ruby
KEYWORDS = {
  # ... existing keywords
  "for" => :FOR,
  "in" => :IN,
  "do" => :DO,
}
```

---

### 3. List Comprehensions

#### Синтаксис
```aurora
[x * 2 for x in arr]                    // Simple map
[x for x in arr if x > 0]              // Filter + map
[x + y for x in arr1 for y in arr2]    // Nested (cartesian product)
```

#### AST Nodes

```ruby
# List comprehension
class ListComprehension < Expr
  attr_reader :output_expr, :generators, :filters

  def initialize(output_expr:, generators:, filters: [], origin: nil)
    super(kind: :list_comp, data: {}, origin: origin)
    @output_expr = output_expr  # Expr - what to collect
    @generators = generators    # Array of {var: String, iterable: Expr}
    @filters = filters          # Array of Expr (conditions)
  end
end

# Generator (part of comprehension)
class Generator < Node
  attr_reader :var_name, :iterable

  def initialize(var_name:, iterable:, origin: nil)
    super(origin: origin)
    @var_name = var_name
    @iterable = iterable
  end
end
```

#### CoreIR Desugaring

List comprehensions деsugаr в комбинацию `map`, `filter`, `flatMap`:

```aurora
[x * 2 for x in arr]
```
↓
```cpp
// Using ranges (C++20)
arr | std::views::transform([](auto x) { return x * 2; }) | std::ranges::to<std::vector>()
```

Или без ranges:
```cpp
std::vector<int> result;
result.reserve(arr.size());
for (auto x : arr) {
  result.push_back(x * 2);
}
```

#### CoreIR Nodes

```ruby
# List comprehension desugars to loop + push
class ListCompExpr < Expr
  attr_reader :element_type, :generators, :filters, :output_expr

  def initialize(element_type:, generators:, filters:, output_expr:, origin: nil)
    # Type is std::vector<element_type>
    array_type = Type.new(kind: :array, name: "array")
    super(kind: :list_comp, data: {}, type: array_type, origin: origin)
    @element_type = element_type
    @generators = generators
    @filters = filters
    @output_expr = output_expr
  end
end
```

#### C++ Lowering

```ruby
def lower_list_comprehension(comp)
  # Generate temporary vector
  result_var = generate_temp_var("comp_result")
  element_type = lower_type(comp.element_type)

  # Create result vector
  result_decl = var_decl(
    "std::vector<#{element_type}>",
    result_var
  )

  # Generate nested loops
  loops = comp.generators.reverse.reduce(nil) do |inner, gen|
    loop_var = gen.var_name
    iterable = lower_expr(gen.iterable)

    # Build loop body
    body_stmts = []

    # Add filter checks
    if comp.filters.any?
      filter_conditions = comp.filters.map { |f| lower_expr(f) }
      combined = filter_conditions.reduce { |acc, cond| binary("&&", acc, cond) }

      # if (filters) { inner_body }
      inner_stmt = if inner
                     inner
                   else
                     # Innermost: push result
                     call(
                       member(id(result_var), ".", "push_back"),
                       [lower_expr(comp.output_expr)]
                     )
                   end

      body_stmts << if_stmt(combined, block(inner_stmt))
    else
      body_stmts << (inner || call(
        member(id(result_var), ".", "push_back"),
        [lower_expr(comp.output_expr)]
      ))
    end

    # Create for loop
    for_range_stmt(
      "auto #{loop_var} : #{iterable.to_source}",
      block(*body_stmts)
    )
  end

  # Wrap in lambda that returns vector
  block(
    result_decl,
    loops,
    id(result_var)
  )
end
```

#### Парсер

```ruby
def parse_list_literal_or_comprehension
  consume(:LBRACKET)

  # Check if it's a comprehension or regular array literal
  # Need to lookahead for "for" keyword

  first_expr = parse_expression

  if current.type == :FOR
    # It's a comprehension: [expr for var in iterable]
    generators = []
    filters = []

    while current.type == :FOR
      consume(:FOR)
      var_name = consume(:IDENTIFIER).value
      consume(:IN)
      iterable = parse_expression

      generators << AST::Generator.new(
        var_name: var_name,
        iterable: iterable
      )

      # Check for filter
      if current.type == :IF
        consume(:IF)
        filters << parse_expression
      end
    end

    consume(:RBRACKET)

    AST::ListComprehension.new(
      output_expr: first_expr,
      generators: generators,
      filters: filters
    )
  else
    # Regular array literal
    elements = [first_expr]

    while current.type == :COMMA
      consume(:COMMA)
      elements << parse_expression
    end

    consume(:RBRACKET)

    AST::ArrayLiteral.new(elements: elements)
  end
end
```

---

### 4. Pipe Operator

#### Синтаксис
```aurora
data |> filter(x => x > 0) |> map(x => x * 2) |> sum()
```

#### AST Nodes

```ruby
# Pipe operation
class PipeOp < Expr
  attr_reader :left, :right

  def initialize(left:, right:, origin: nil)
    super(kind: :pipe, data: {left: left, right: right}, origin: origin)
    @left = left    # Expr - value being piped
    @right = right  # Expr - usually Call, receives left as first arg
  end
end
```

#### CoreIR Desugaring

Pipe operator десugаrs в обычные function calls:

```aurora
data |> filter(pred) |> map(f)
```
↓
```ruby
map(filter(data, pred), f)
```

Или в C++:
```cpp
map(filter(data, pred), f)
```

#### CoreIR Transformation

```ruby
def transform_pipe_op(pipe, ctx)
  # Desugar: left |> f(args) => f(left, args)

  left_expr = transform_expr(pipe.left, ctx)

  # Right side should be a Call
  if pipe.right.is_a?(AST::Call)
    callee = transform_expr(pipe.right.callee, ctx)
    args = pipe.right.args.map { |a| transform_expr(a, ctx) }

    # Insert left as first argument
    all_args = [left_expr] + args

    # Infer return type
    ret_type = infer_call_type(callee, all_args, ctx)

    CoreIR::CallExpr.new(
      callee: callee,
      args: all_args,
      type: ret_type
    )
  else
    # Right side is just a function name
    callee = transform_expr(pipe.right, ctx)

    ret_type = infer_call_type(callee, [left_expr], ctx)

    CoreIR::CallExpr.new(
      callee: callee,
      args: [left_expr],
      type: ret_type
    )
  end
end
```

#### Парсер

```ruby
def parse_pipe_expression
  # Pipe has lower precedence than most operators
  left = parse_comparison_expression

  while current.type == :OPERATOR && current.value == "|>"
    consume_operator("|>")
    right = parse_comparison_expression

    left = AST::PipeOp.new(left: left, right: right)
  end

  left
end

def parse_expression
  parse_pipe_expression
end
```

#### Лексер

```ruby
def scan_operator
  # ... existing operator logic

  if current_char == '|'
    advance
    if current_char == '>'
      advance
      return Token.new(:OPERATOR, "|>", line: @line, column: @column)
    else
      # Regular | (bitwise or)
      return Token.new(:OPERATOR, "|", line: @line, column: @column)
    end
  end
end
```

---

### 5. Function Types

#### Синтаксис
```aurora
fn map(arr: i32[], f: i32 -> i32) -> i32[] = ...
fn compose(f: i32 -> i32, g: i32 -> i32) -> i32 -> i32 = ...
```

#### AST Nodes

```ruby
# Function type
class FunctionType < Type
  attr_reader :param_types, :ret_type

  def initialize(param_types:, ret_type:, origin: nil)
    super(kind: :func, name: "function", origin: origin)
    @param_types = param_types  # Array of Type
    @ret_type = ret_type
  end
end
```

#### C++ Lowering

```ruby
def lower_function_type(func_type)
  param_types_str = func_type.param_types.map { |t| lower_type(t) }.join(", ")
  ret_type_str = lower_type(func_type.ret_type)

  # std::function<RetType(ParamTypes...)>
  "std::function<#{ret_type_str}(#{param_types_str})>"
end
```

#### Парсер

```ruby
def parse_type
  base = parse_primary_type

  # Check for function type arrow: ->
  if current.type == :ARROW
    consume(:ARROW)
    ret_type = parse_type  # Right-associative

    # base -> ret_type means function taking base and returning ret_type
    param_types = if base.is_a?(AST::TupleType)
                    base.types
                  else
                    [base]
                  end

    AST::FunctionType.new(
      param_types: param_types,
      ret_type: ret_type
    )
  else
    base
  end
end

def parse_primary_type
  case current.type
  when :LPAREN
    # Tuple type or grouped type
    consume(:LPAREN)

    types = []
    types << parse_type

    if current.type == :COMMA
      # It's a tuple
      while current.type == :COMMA
        consume(:COMMA)
        types << parse_type
      end
      consume(:RPAREN)
      AST::TupleType.new(types: types)
    else
      # Just a grouped type
      consume(:RPAREN)
      types[0]
    end
  when :I32, :F32, :BOOL, :VOID, :STR, :IDENTIFIER
    # Regular types
    # ... existing logic
  end
end
```

---

## Порядок реализации

### Phase 1: Lambda Expressions (Приоритет 1)
1. ✅ Добавить tokens: `ARROW` (`=>`)
2. ✅ Добавить AST nodes: `Lambda`, `LambdaParam`, `FunctionType`
3. ✅ Реализовать парсинг lambda expressions
4. ✅ Добавить CoreIR nodes: `LambdaExpr`, `FunctionType`
5. ✅ Реализовать type inference для lambdas
6. ✅ Реализовать capture analysis
7. ✅ Реализовать C++ lowering в C++ lambdas
8. ✅ Тестирование

### Phase 2: For Loops (Приоритет 2)
1. ✅ Добавить keywords: `for`, `in`, `do`
2. ✅ Добавить AST nodes: `ForLoop`, `RangeExpr`
3. ✅ Реализовать парсинг for loops
4. ✅ Добавить CoreIR nodes: `ForLoop`
5. ✅ Реализовать C++ lowering в range-based for
6. ✅ Тестирование

### Phase 3: List Comprehensions (Приоритет 3)
1. ✅ Добавить AST nodes: `ListComprehension`, `Generator`
2. ✅ Реализовать парсинг comprehensions (сложный lookahead)
3. ✅ Реализовать desugaring в CoreIR
4. ✅ Реализовать C++ lowering (loop + vector)
5. ✅ Тестирование

### Phase 4: Pipe Operator (Приоритет 4)
1. ✅ Добавить token: `|>` operator
2. ✅ Добавить AST node: `PipeOp`
3. ✅ Реализовать парсинг (низкий precedence)
4. ✅ Реализовать desugaring в function calls
5. ✅ Тестирование

### Phase 5: Function Types (Приоритет 5)
1. ✅ Расширить type parser для `->` syntax
2. ✅ Добавить AST node: `FunctionType`
3. ✅ Реализовать C++ lowering в `std::function`
4. ✅ Интеграция с lambda expressions
5. ✅ Тестирование

---

## Примеры использования

### Lambda Expressions

**Aurora:**
```aurora
fn map(arr: i32[], f: i32 -> i32) -> i32[] =
  [f(x) for x in arr]

fn main() -> void =
  let nums = [1, 2, 3, 4, 5]
  let doubled = map(nums, x => x * 2)
  doubled
```

**Generated C++:**
```cpp
std::vector<int> map(std::vector<int> arr, std::function<int(int)> f) {
  std::vector<int> result;
  result.reserve(arr.size());
  for (auto x : arr) {
    result.push_back(f(x));
  }
  return result;
}

void main() {
  auto nums = std::vector<int>{1, 2, 3, 4, 5};
  auto doubled = map(nums, [](int x) { return x * 2; });
}
```

### For Loops + List Comprehensions

**Aurora:**
```aurora
fn sum_array(arr: i32[]) -> i32 =
  let sum = 0
  for x in arr do
    sum = sum + x
  sum

fn filter_map(arr: i32[]) -> i32[] =
  [x * 2 for x in arr if x > 0]
```

**Generated C++:**
```cpp
int sum_array(std::vector<int> arr) {
  int sum = 0;
  for (auto x : arr) {
    sum = sum + x;
  }
  return sum;
}

std::vector<int> filter_map(std::vector<int> arr) {
  std::vector<int> result;
  for (auto x : arr) {
    if (x > 0) {
      result.push_back(x * 2);
    }
  }
  return result;
}
```

### Pipe Operator

**Aurora:**
```aurora
fn process_data(data: f32[]) -> f32 =
  data
    |> filter(x => x > 0.0)
    |> map(x => x * 2.0)
    |> sum()
```

**Generated C++:**
```cpp
float process_data(std::vector<float> data) {
  return sum(
    map(
      filter(data, [](float x) { return x > 0.0; }),
      [](float x) { return x * 2.0; }
    )
  );
}
```

---

## Проблемы и решения

### 1. Lambda Capture Analysis

**Проблема:** Нужно определить, какие переменные захватывать из окружения.

**Решение:**
- Во время transformation AST → CoreIR делать анализ свободных переменных
- Трекать scope и определять, какие variables используются но не определены в lambda
- Создавать список captures с правильными modes (value/reference)

```ruby
class CaptureAnalyzer
  def analyze(lambda_body, enclosing_scope)
    free_vars = find_free_variables(lambda_body)
    captures = []

    free_vars.each do |var_name|
      var_info = enclosing_scope.lookup(var_name)
      mode = var_info.mutable? ? :ref : :value

      captures << {
        name: var_name,
        type: var_info.type,
        mode: mode
      }
    end

    captures
  end

  def find_free_variables(expr, bound_vars = Set.new)
    case expr
    when AST::VarRef
      expr.name unless bound_vars.include?(expr.name)
    when AST::Lambda
      # Add lambda params to bound vars
      new_bound = bound_vars + expr.params.map(&:name).to_set
      find_free_variables(expr.body, new_bound)
    # ... other cases
    end
  end
end
```

### 2. List Comprehension Lookahead

**Проблема:** Нужно различать `[expr, expr, ...]` и `[expr for var in ...]`

**Решение:** После parsing первого expression смотреть на следующий token:
- Если `,` → array literal
- Если `for` → comprehension
- Если `]` → single-element array

### 3. Pipe Operator Precedence

**Проблема:** Нужна правильная precedence для `|>`

**Решение:** Pipe имеет самый низкий precedence, ниже всех бинарных операторов:
```
expression := pipe_expr
pipe_expr := comparison (|> comparison)*
comparison := additive (< | > | == | ...) additive
additive := multiplicative (+ | -) multiplicative
...
```

### 4. Function Type Parsing

**Проблема:** Нужна right-associative precedence для `->`:
`i32 -> i32 -> i32` должно парситься как `i32 -> (i32 -> i32)`

**Решение:** Рекурсивный descent с правой рекурсией:
```ruby
def parse_type
  base = parse_primary_type

  if current.type == :ARROW
    consume(:ARROW)
    ret_type = parse_type  # RIGHT recursive
    AST::FunctionType.new(param_types: [base], ret_type: ret_type)
  else
    base
  end
end
```

---

## Тестирование

### Test Cases

#### Lambda Expressions
```ruby
def test_simple_lambda
  source = "fn main() -> void = let f = x => x * 2"
  ast = Aurora.parse(source)
  cpp = Aurora.to_cpp(source)
  assert cpp.include?("[](auto x) { return x * 2; }")
end

def test_lambda_with_types
  source = "fn main() -> void = let f = (x: i32) => x + 1"
  cpp = Aurora.to_cpp(source)
  assert cpp.include?("[](int x) { return x + 1; }")
end

def test_lambda_capture
  source = <<~AURORA
    fn main() -> void =
      let y = 10
      let f = x => x + y
  AURORA
  cpp = Aurora.to_cpp(source)
  assert cpp.include?("[y](auto x)")
end
```

#### For Loops
```ruby
def test_for_loop_simple
  source = <<~AURORA
    fn sum(arr: i32[]) -> i32 =
      let s = 0
      for x in arr do
        s = s + x
      s
  AURORA
  cpp = Aurora.to_cpp(source)
  assert cpp.include?("for (auto x : arr)")
end
```

#### List Comprehensions
```ruby
def test_list_comprehension_simple
  source = "fn main() -> i32[] = [x * 2 for x in [1,2,3]]"
  cpp = Aurora.to_cpp(source)
  assert cpp.include?("result.push_back(x * 2)")
end

def test_list_comprehension_with_filter
  source = "fn main() -> i32[] = [x for x in arr if x > 0]"
  cpp = Aurora.to_cpp(source)
  assert cpp.include?("if (x > 0)")
  assert cpp.include?("result.push_back(x)")
end
```

#### Pipe Operator
```ruby
def test_pipe_operator
  source = "fn main() -> i32 = 5 |> add(3) |> mul(2)"
  cpp = Aurora.to_cpp(source)
  assert cpp.include?("mul(add(5, 3), 2)")
end
```

---

## Заключение

Эта архитектура предоставляет полную roadmap для реализации продвинутых функций Aurora:

✅ **Lambda expressions** - высокоприоритетная функция, необходима для функционального стиля
✅ **For loops** - базовая императивная конструкция
✅ **List comprehensions** - синтаксический сахар над for loops
✅ **Pipe operator** - элегантная композиция функций
✅ **Function types** - необходимы для higher-order functions

Все функции интегрируются с существующей архитектурой Aurora и следуют паттерну:
```
AST → CoreIR Desugaring → C++ Lowering
```

Реализация займет примерно **2-3 недели** для всех фич.

---

**Next Steps:**
1. Начать с Phase 1: Lambda Expressions
2. Реализовать по одной phase за раз
3. Писать тесты для каждой feature
4. После всех phases - integration testing

**Status:** ✅ Architecture Complete - Ready for Implementation

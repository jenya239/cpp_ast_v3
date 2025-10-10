# Руководство по реализации C++ AST Parser для AI Агента
# Complete Implementation Guide from Scratch

## 📋 Оглавление

1. [Анализ текущих проблем](#1-анализ-текущих-проблем)
2. [Архитектурные принципы](#2-архитектурные-принципы)
3. [Структура проекта](#3-структура-проекта)
4. [TDD Workflow](#4-tdd-workflow)
5. [Пошаговая реализация](#5-пошаговая-реализация)
6. [Контрольные точки](#6-контрольные-точки)

---

## 1. Анализ текущих проблем

### 1.1 Критические архитектурные проблемы

#### ❌ Проблема 1: Inconsistent Trivia Ownership
```ruby
# ПЛОХО: Node владеет trailing trivia
class Identifier
  attr_accessor :name, :trailing_trivia
  
  def to_source
    "#{name}#{trailing_trivia}"  # Identifier не должен знать что после него!
  end
end
```

**Почему плохо:**
- Node отвечает за то, что ПОСЛЕ него (нарушение SRP)
- При композиции trailing дублируется
- Сложно отследить ownership trivia
- Невозможно гарантировать roundtrip

#### ❌ Проблема 2: Implicit Trivia Flow
```ruby
# Триvia "исчезает" внутри parse методов
def parse_expression
  # Куда делся whitespace? Неизвестно!
  expr = SomeExpression.new(...)
  expr  # Где trailing? Потерян!
end
```

#### ❌ Проблема 3: Mixing Concerns
```ruby
# Parser делает ВСЁ (8600+ строк!)
class Parser
  include ExpressionParser
  include StatementParser
  include DeclarationParser
  include Diagnostics
  include StateManager
  # ... еще 20 concerns
end
```

#### ❌ Проблема 4: Duplicate Node Classes
```ruby
# nodes/expression_nodes.rb - простые версии БЕЗ trivia
class BinaryExpression
  attr_accessor :left, :operator, :right
end

# nodes.rb - версии С trivia
class BinaryExpression
  attr_accessor :left, :operator, :right, :operator_prefix, :operator_suffix
end
```

#### ❌ Проблема 5: No Clear Module Boundaries
- Lexer, Parser, Nodes все зависят друг от друга
- Circular dependencies
- Невозможно переиспользовать компоненты

### 1.2 Что нужно достичь

✅ **100% Roundtrip Accuracy**: `source -> AST -> to_source == source`
✅ **Clear Separation**: Expression, Statement, Declaration парсеры независимы
✅ **Explicit Trivia**: Каждый parse метод возвращает `(node, trailing_trivia)`
✅ **Parent Ownership**: Родитель владеет spacing между детьми
✅ **TDD from Day 1**: Каждая фича начинается с теста

---

## 2. Архитектурные принципы

### 2.1 Core Design Principles

#### Principle 1: Single Responsibility per Node
**Каждый node отвечает только за свой синтаксис, не за spacing**

```ruby
# ✅ ПРАВИЛЬНО
class Identifier < Expression
  attr_accessor :name
  
  def initialize(name:)
    @name = name
  end
  
  def to_source
    name  # Только имя, триvia отдельно
  end
end
```

#### Principle 2: Explicit Trivia Flow
**Триvia передается явно через return values**

```ruby
# ✅ ПРАВИЛЬНО: Все parse методы возвращают tuples
def parse_expression
  expr = create_expression
  trailing = collect_trivia_string
  [expr, trailing]  # Явно возвращаем trailing
end

# Использование
expr, trailing = parse_expression
```

#### Principle 3: Parent Ownership of Spacing
**Родительский node владеет spacing между children**

```ruby
# ✅ ПРАВИЛЬНО
class Program < Node
  attr_accessor :statements, :statement_trailings
  
  def initialize(statements:, statement_trailings:)
    @statements = statements
    @statement_trailings = statement_trailings
  end
  
  def to_source
    statements.zip(statement_trailings).map { |stmt, trailing|
      stmt.to_source + trailing
    }.join
  end
end
```

#### Principle 4: Immutable Nodes
**Nodes are immutable after creation**

```ruby
# ✅ ПРАВИЛЬНО: Create new node for modifications
class Rewriter
  def replace_expression(old_expr, new_expr)
    # Создать новое дерево, не мутировать старое
    Program.new(
      statements: statements.map { |s| s == old_expr ? new_expr : s }
    )
  end
end
```

#### Principle 5: Layered Architecture
**Четкое разделение слоев**

```
┌─────────────────────┐
│   Rewriter Layer    │ ← Модификация AST
├─────────────────────┤
│    Parser Layer     │ ← Парсинг в AST
├─────────────────────┤
│    Lexer Layer      │ ← Токенизация
├─────────────────────┤
│   Source Text       │
└─────────────────────┘
```

### 2.2 Module Organization

```
cpp_ast/
├── lexer/           ← Tokenization layer
│   ├── lexer.rb
│   ├── token.rb
│   └── lexer_helpers/
│       ├── literals.rb
│       ├── comments.rb
│       └── preprocessor.rb
│
├── nodes/           ← AST node definitions (PURE DATA)
│   ├── base.rb
│   ├── expressions.rb
│   ├── statements.rb
│   └── declarations.rb
│
├── parsers/         ← Parsing logic (NO MIXING)
│   ├── base_parser.rb       ← Common utilities
│   ├── expression_parser.rb ← Only expressions
│   ├── statement_parser.rb  ← Only statements
│   └── declaration_parser.rb ← Only declarations
│
├── rewriters/       ← AST manipulation
│   └── rewriter.rb
│
└── cpp_ast.rb       ← Public API
```

**Ключевые правила:**
- ✅ `nodes/` НЕ зависит от `parsers/`
- ✅ `parsers/` НЕ зависят друг от друга (только от base_parser)
- ✅ `lexer/` НЕ зависит ни от чего
- ✅ Каждый модуль в отдельном файле (<500 строк)

---

## 3. Структура проекта

### 3.1 Создание новой папки проекта

```bash
# Создать новую папку
mkdir -p /home/jenya/workspaces/experimental/cpp_ast_v3
cd /home/jenya/workspaces/experimental/cpp_ast_v3

# Структура
mkdir -p lib/cpp_ast/{lexer,nodes,parsers,rewriters}
mkdir -p lib/cpp_ast/lexer/helpers
mkdir -p test/{lexer,nodes,parsers,integration}
mkdir -p test/fixtures
```

### 3.2 Полная структура директорий

```
cpp_ast_v3/
├── lib/
│   └── cpp_ast/
│       ├── cpp_ast.rb                    # Public API
│       │
│       ├── lexer/
│       │   ├── token.rb                  # Token class (50 lines)
│       │   ├── lexer.rb                  # Main lexer (200 lines)
│       │   └── helpers/
│       │       ├── literals.rb           # Number/string literals (150 lines)
│       │       ├── comments.rb           # Comment handling (80 lines)
│       │       └── preprocessor.rb       # Preprocessor directives (100 lines)
│       │
│       ├── nodes/
│       │   ├── base.rb                   # Node, Expression, Statement (80 lines)
│       │   ├── expressions.rb            # All expression nodes (300 lines)
│       │   ├── statements.rb             # All statement nodes (250 lines)
│       │   └── declarations.rb           # All declaration nodes (200 lines)
│       │
│       ├── parsers/
│       │   ├── base_parser.rb            # Common parser utilities (150 lines)
│       │   ├── expression_parser.rb      # Expression parsing (350 lines)
│       │   ├── statement_parser.rb       # Statement parsing (300 lines)
│       │   └── declaration_parser.rb     # Declaration parsing (250 lines)
│       │
│       └── rewriters/
│           └── rewriter.rb               # AST manipulation (150 lines)
│
├── test/
│   ├── test_helper.rb                    # Common test utilities
│   │
│   ├── lexer/
│   │   ├── test_lexer_basic.rb
│   │   ├── test_lexer_literals.rb
│   │   └── test_lexer_comments.rb
│   │
│   ├── nodes/
│   │   ├── test_expression_nodes.rb
│   │   ├── test_statement_nodes.rb
│   │   └── test_declaration_nodes.rb
│   │
│   ├── parsers/
│   │   ├── test_expression_parser.rb
│   │   ├── test_statement_parser.rb
│   │   └── test_declaration_parser.rb
│   │
│   ├── integration/
│   │   ├── test_roundtrip.rb             # Roundtrip tests
│   │   └── test_rewriter.rb              # Rewriter tests
│   │
│   └── fixtures/
│       ├── simple_expression.cpp
│       ├── function_definition.cpp
│       └── complex_program.cpp
│
├── Gemfile                                # Dependencies
├── Rakefile                               # Build tasks
└── README.md                              # Documentation
```

**Максимальный размер файла: 400 строк**

---

## 4. TDD Workflow

### 4.1 Red-Green-Refactor Cycle

```
┌─────────────┐
│  1. RED     │ ← Write failing test
└──────┬──────┘
       │
       ▼
┌─────────────┐
│  2. GREEN   │ ← Make it pass (простейшим способом)
└──────┬──────┘
       │
       ▼
┌─────────────┐
│  3. REFACTOR│ ← Улучшить код
└──────┬──────┘
       │
       └──────┐
              │
              ▼
        (repeat)
```

### 4.2 Test Organization

#### Unit Tests (Fast, Isolated)
```ruby
# test/nodes/test_expression_nodes.rb
class TestExpressionNodes < Minitest::Test
  def test_identifier_to_source
    node = CppAst::Nodes::Identifier.new(name: "foo")
    assert_equal "foo", node.to_source
  end
  
  def test_identifier_does_not_include_trivia
    node = CppAst::Nodes::Identifier.new(name: "foo")
    refute_includes node.to_source, "\n"
  end
end
```

#### Integration Tests (Slower, End-to-End)
```ruby
# test/integration/test_roundtrip.rb
class TestRoundtrip < Minitest::Test
  def test_simple_expression_roundtrip
    source = "x = 42;\n"
    
    lexer = CppAst::Lexer.new(source)
    parser = CppAst::Parser.new(lexer)
    program = parser.parse
    
    assert_equal source, program.to_source
  end
end
```

### 4.3 Test Naming Convention

```ruby
# Pattern: test_<feature>_<scenario>_<expectation>
test_binary_expression_with_whitespace_preserves_spacing
test_unary_expression_without_operand_raises_error
test_parenthesized_expression_nested_preserves_parens
```

---

## 5. Пошаговая реализация

### Phase 0: Setup (30 минут)

#### Step 0.1: Create Project Structure
```bash
# Create directories
mkdir -p /home/jenya/workspaces/experimental/cpp_ast_v3/{lib,test}/cpp_ast
cd /home/jenya/workspaces/experimental/cpp_ast_v3

# Create subdirectories
mkdir -p lib/cpp_ast/{lexer/helpers,nodes,parsers,rewriters}
mkdir -p test/{lexer,nodes,parsers,integration,fixtures}
```

#### Step 0.2: Create Gemfile
```ruby
# Gemfile
source "https://rubygems.org"

gem "minitest", "~> 5.0"
gem "rake", "~> 13.0"

group :development do
  gem "debug"
end
```

#### Step 0.3: Create test_helper.rb
```ruby
# test/test_helper.rb
require "minitest/autorun"
require "minitest/pride"
require_relative "../lib/cpp_ast"

module TestHelpers
  def assert_roundtrip(source)
    lexer = CppAst::Lexer.new(source)
    parser = CppAst::Parser.new(lexer)
    program = parser.parse
    
    assert_equal source, program.to_source, 
      "Roundtrip failed: source != AST.to_source"
  end
end

class Minitest::Test
  include TestHelpers
end
```

#### Step 0.4: Create Rakefile
```ruby
# Rakefile
require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/**/*_test.rb"]
  t.verbose = true
end

task default: :test
```

---

### Phase 1: Lexer (2-3 часа)

#### Step 1.1: Token Class (TDD)

**Test First:**
```ruby
# test/lexer/test_token.rb
require_relative "../test_helper"

class TestToken < Minitest::Test
  def test_token_creation
    token = CppAst::Token.new(kind: :identifier, lexeme: "foo", line: 1, column: 0)
    
    assert_equal :identifier, token.kind
    assert_equal "foo", token.lexeme
    assert_equal 1, token.line
    assert_equal 0, token.column
  end
  
  def test_token_trivia_check
    assert CppAst::Token.trivia?(:whitespace)
    assert CppAst::Token.trivia?(:comment)
    refute CppAst::Token.trivia?(:identifier)
  end
end
```

**Implementation:**
```ruby
# lib/cpp_ast/lexer/token.rb
module CppAst
  class Token
    attr_reader :kind, :lexeme, :line, :column
    
    TRIVIA_KINDS = [:whitespace, :comment, :newline].freeze
    
    def initialize(kind:, lexeme:, line:, column:)
      @kind = kind
      @lexeme = lexeme
      @line = line
      @column = column
    end
    
    def self.trivia?(kind)
      TRIVIA_KINDS.include?(kind)
    end
    
    def trivia?
      self.class.trivia?(kind)
    end
    
    def to_s
      "Token(#{kind}, #{lexeme.inspect}, #{line}:#{column})"
    end
  end
end
```

**Run Test:**
```bash
ruby test/lexer/test_token.rb
# Expected: 2 tests, 5 assertions, 0 failures
```

#### Step 1.2: Lexer Core (TDD)

**Test First:**
```ruby
# test/lexer/test_lexer_basic.rb
require_relative "../test_helper"

class TestLexerBasic < Minitest::Test
  def test_lex_identifier
    lexer = CppAst::Lexer.new("foo")
    tokens = lexer.tokenize
    
    assert_equal 2, tokens.size
    assert_equal :identifier, tokens[0].kind
    assert_equal "foo", tokens[0].lexeme
    assert_equal :eof, tokens[1].kind
  end
  
  def test_lex_with_whitespace
    lexer = CppAst::Lexer.new("foo bar")
    tokens = lexer.tokenize
    
    assert_equal 4, tokens.size
    assert_equal :identifier, tokens[0].kind
    assert_equal :whitespace, tokens[1].kind
    assert_equal :identifier, tokens[2].kind
    assert_equal :eof, tokens[3].kind
  end
  
  def test_lex_operators
    lexer = CppAst::Lexer.new("x = 42;")
    tokens = lexer.tokenize
    
    kinds = tokens.map(&:kind)
    assert_equal [:identifier, :whitespace, :equals, :whitespace, 
                  :number, :semicolon, :eof], kinds
  end
end
```

**Implementation:**
```ruby
# lib/cpp_ast/lexer/lexer.rb
module CppAst
  class Lexer
    attr_reader :source, :position, :line, :column
    
    def initialize(source)
      @source = source
      @position = 0
      @line = 1
      @column = 0
    end
    
    def tokenize
      tokens = []
      
      until at_end?
        token = scan_token
        tokens << token if token
      end
      
      tokens << Token.new(kind: :eof, lexeme: "", line: @line, column: @column)
      tokens
    end
    
    private
    
    def at_end?
      @position >= @source.length
    end
    
    def current_char
      return nil if at_end?
      @source[@position]
    end
    
    def peek(offset = 0)
      pos = @position + offset
      return nil if pos >= @source.length
      @source[pos]
    end
    
    def advance
      char = current_char
      @position += 1
      @column += 1
      
      if char == "\n"
        @line += 1
        @column = 0
      end
      
      char
    end
    
    def scan_token
      start_line = @line
      start_column = @column
      char = advance
      
      case char
      when /\s/
        scan_whitespace(char, start_line, start_column)
      when /[a-zA-Z_]/
        scan_identifier(char, start_line, start_column)
      when /[0-9]/
        scan_number(char, start_line, start_column)
      when "="
        Token.new(kind: :equals, lexeme: "=", line: start_line, column: start_column)
      when ";"
        Token.new(kind: :semicolon, lexeme: ";", line: start_line, column: start_column)
      when "+"
        Token.new(kind: :plus, lexeme: "+", line: start_line, column: start_column)
      when "-"
        Token.new(kind: :minus, lexeme: "-", line: start_line, column: start_column)
      when "*"
        Token.new(kind: :asterisk, lexeme: "*", line: start_line, column: start_column)
      when "/"
        if peek == "/"
          scan_line_comment(start_line, start_column)
        else
          Token.new(kind: :slash, lexeme: "/", line: start_line, column: start_column)
        end
      else
        raise "Unexpected character: #{char.inspect} at #{start_line}:#{start_column}"
      end
    end
    
    def scan_whitespace(first_char, line, column)
      lexeme = first_char
      
      while current_char&.match?(/\s/) && current_char != "\n"
        lexeme << advance
      end
      
      Token.new(kind: :whitespace, lexeme: lexeme, line: line, column: column)
    end
    
    def scan_identifier(first_char, line, column)
      lexeme = first_char
      
      while current_char&.match?(/[a-zA-Z0-9_]/)
        lexeme << advance
      end
      
      Token.new(kind: :identifier, lexeme: lexeme, line: line, column: column)
    end
    
    def scan_number(first_char, line, column)
      lexeme = first_char
      
      while current_char&.match?(/[0-9]/)
        lexeme << advance
      end
      
      Token.new(kind: :number, lexeme: lexeme, line: line, column: column)
    end
    
    def scan_line_comment(line, column)
      advance  # skip second /
      lexeme = "//"
      
      while current_char && current_char != "\n"
        lexeme << advance
      end
      
      Token.new(kind: :comment, lexeme: lexeme, line: line, column: column)
    end
  end
end
```

**Run Test:**
```bash
ruby test/lexer/test_lexer_basic.rb
# Expected: 3 tests, ~15 assertions, 0 failures
```

---

### Phase 2: Nodes (1-2 часа)

#### Step 2.1: Base Node Classes (TDD)

**Test First:**
```ruby
# test/nodes/test_base_nodes.rb
require_relative "../test_helper"

class TestBaseNodes < Minitest::Test
  def test_node_is_abstract
    assert_raises(NotImplementedError) do
      CppAst::Nodes::Node.new.to_source
    end
  end
  
  def test_expression_is_abstract
    assert_raises(NotImplementedError) do
      CppAst::Nodes::Expression.new.to_source
    end
  end
  
  def test_statement_has_leading_trivia
    stmt = CppAst::Nodes::Statement.new(leading_trivia: "  ")
    assert_equal "  ", stmt.leading_trivia
  end
end
```

**Implementation:**
```ruby
# lib/cpp_ast/nodes/base.rb
module CppAst
  module Nodes
    # Base node - все nodes наследуются от него
    class Node
      def to_source
        raise NotImplementedError, "#{self.class} must implement #to_source"
      end
      
      def ==(other)
        return false unless other.is_a?(self.class)
        instance_variables.all? do |var|
          instance_variable_get(var) == other.instance_variable_get(var)
        end
      end
    end
    
    # Expression - БЕЗ trivia (контролируется parent)
    class Expression < Node
      # Expressions не имеют leading_trivia
      # Parent управляет spacing
    end
    
    # Statement - С leading trivia (индентация перед statement)
    class Statement < Node
      attr_accessor :leading_trivia
      
      def initialize(leading_trivia: "")
        @leading_trivia = leading_trivia
      end
    end
  end
end
```

#### Step 2.2: Expression Nodes (TDD)

**Test First:**
```ruby
# test/nodes/test_expression_nodes.rb
require_relative "../test_helper"

class TestExpressionNodes < Minitest::Test
  # Identifier
  def test_identifier_to_source
    node = CppAst::Nodes::Identifier.new(name: "foo")
    assert_equal "foo", node.to_source
  end
  
  def test_identifier_equality
    node1 = CppAst::Nodes::Identifier.new(name: "foo")
    node2 = CppAst::Nodes::Identifier.new(name: "foo")
    node3 = CppAst::Nodes::Identifier.new(name: "bar")
    
    assert_equal node1, node2
    refute_equal node1, node3
  end
  
  # NumberLiteral
  def test_number_literal_to_source
    node = CppAst::Nodes::NumberLiteral.new(value: "42")
    assert_equal "42", node.to_source
  end
  
  # BinaryExpression
  def test_binary_expression_simple
    left = CppAst::Nodes::Identifier.new(name: "x")
    right = CppAst::Nodes::NumberLiteral.new(value: "42")
    node = CppAst::Nodes::BinaryExpression.new(
      left: left,
      operator: "+",
      right: right
    )
    
    assert_equal "x+42", node.to_source
  end
  
  def test_binary_expression_with_spacing
    left = CppAst::Nodes::Identifier.new(name: "x")
    right = CppAst::Nodes::NumberLiteral.new(value: "42")
    node = CppAst::Nodes::BinaryExpression.new(
      left: left,
      operator: "+",
      operator_prefix: " ",
      operator_suffix: " ",
      right: right
    )
    
    assert_equal "x + 42", node.to_source
  end
end
```

**Implementation:**
```ruby
# lib/cpp_ast/nodes/expressions.rb
module CppAst
  module Nodes
    # Identifier - простейший expression
    class Identifier < Expression
      attr_accessor :name
      
      def initialize(name:)
        @name = name
      end
      
      def to_source
        name
      end
    end
    
    # NumberLiteral
    class NumberLiteral < Expression
      attr_accessor :value
      
      def initialize(value:)
        @value = value
      end
      
      def to_source
        value
      end
    end
    
    # BinaryExpression
    class BinaryExpression < Expression
      attr_accessor :left, :operator, :right, :operator_prefix, :operator_suffix
      
      def initialize(left:, operator:, right:, operator_prefix: "", operator_suffix: "")
        @left = left
        @operator = operator
        @right = right
        @operator_prefix = operator_prefix
        @operator_suffix = operator_suffix
      end
      
      def to_source
        "#{left.to_source}#{operator_prefix}#{operator}#{operator_suffix}#{right.to_source}"
      end
    end
    
    # UnaryExpression
    class UnaryExpression < Expression
      attr_accessor :operator, :operand, :operator_suffix, :prefix
      
      def initialize(operator:, operand:, operator_suffix: "", prefix: true)
        @operator = operator
        @operand = operand
        @operator_suffix = operator_suffix
        @prefix = prefix
      end
      
      def to_source
        if prefix
          "#{operator}#{operator_suffix}#{operand.to_source}"
        else
          "#{operand.to_source}#{operator}"
        end
      end
    end
  end
end
```

**Run Test:**
```bash
ruby test/nodes/test_expression_nodes.rb
# Expected: ~6 tests, ~10 assertions, 0 failures
```

#### Step 2.3: Statement Nodes (TDD)

**Test First:**
```ruby
# test/nodes/test_statement_nodes.rb
require_relative "../test_helper"

class TestStatementNodes < Minitest::Test
  def test_expression_statement_without_trivia
    expr = CppAst::Nodes::Identifier.new(name: "foo")
    stmt = CppAst::Nodes::ExpressionStatement.new(expression: expr)
    
    assert_equal "foo;", stmt.to_source
  end
  
  def test_expression_statement_with_leading_trivia
    expr = CppAst::Nodes::Identifier.new(name: "foo")
    stmt = CppAst::Nodes::ExpressionStatement.new(
      leading_trivia: "  ",
      expression: expr
    )
    
    assert_equal "  foo;", stmt.to_source
  end
  
  def test_return_statement
    expr = CppAst::Nodes::NumberLiteral.new(value: "42")
    stmt = CppAst::Nodes::ReturnStatement.new(
      expression: expr,
      keyword_suffix: " "
    )
    
    assert_equal "return 42;", stmt.to_source
  end
end
```

**Implementation:**
```ruby
# lib/cpp_ast/nodes/statements.rb
module CppAst
  module Nodes
    # ExpressionStatement: `foo;`
    class ExpressionStatement < Statement
      attr_accessor :expression
      
      def initialize(leading_trivia: "", expression:)
        super(leading_trivia: leading_trivia)
        @expression = expression
      end
      
      def to_source
        "#{leading_trivia}#{expression.to_source};"
      end
    end
    
    # ReturnStatement: `return 42;`
    class ReturnStatement < Statement
      attr_accessor :expression, :keyword_suffix
      
      def initialize(leading_trivia: "", expression:, keyword_suffix: " ")
        super(leading_trivia: leading_trivia)
        @expression = expression
        @keyword_suffix = keyword_suffix
      end
      
      def to_source
        "#{leading_trivia}return#{keyword_suffix}#{expression.to_source};"
      end
    end
    
    # Program: Top-level container
    class Program < Node
      attr_accessor :statements, :statement_trailings
      
      def initialize(statements:, statement_trailings:)
        @statements = statements
        @statement_trailings = statement_trailings
      end
      
      def to_source
        statements.zip(statement_trailings).map { |stmt, trailing|
          stmt.to_source + trailing
        }.join
      end
    end
  end
end
```

**Run Test:**
```bash
ruby test/nodes/test_statement_nodes.rb
# Expected: 3 tests, ~5 assertions, 0 failures
```

---

### Phase 3: Parsers (4-6 часов)

#### Step 3.1: Base Parser (TDD)

**Test First:**
```ruby
# test/parsers/test_base_parser.rb
require_relative "../test_helper"

class TestBaseParser < Minitest::Test
  def setup
    @lexer = CppAst::Lexer.new("foo bar")
    @parser = CppAst::Parsers::BaseParser.new(@lexer)
  end
  
  def test_current_token
    assert_equal :identifier, @parser.current_token.kind
    assert_equal "foo", @parser.current_token.lexeme
  end
  
  def test_advance_raw
    @parser.advance_raw
    assert_equal :whitespace, @parser.current_token.kind
  end
  
  def test_collect_trivia_string
    @parser.advance_raw  # move to whitespace
    trivia = @parser.collect_trivia_string
    
    assert_equal " ", trivia
    assert_equal :identifier, @parser.current_token.kind
    assert_equal "bar", @parser.current_token.lexeme
  end
  
  def test_expect_token
    @parser.expect(:identifier)
    assert_equal :whitespace, @parser.current_token.kind
  end
  
  def test_expect_token_raises_on_mismatch
    assert_raises(CppAst::ParseError) do
      @parser.expect(:semicolon)
    end
  end
end
```

**Implementation:**
```ruby
# lib/cpp_ast/parsers/base_parser.rb
module CppAst
  class ParseError < StandardError; end
  
  module Parsers
    class BaseParser
      attr_reader :tokens, :position
      
      def initialize(lexer)
        @tokens = lexer.tokenize
        @position = 0
      end
      
      def current_token
        @tokens[@position]
      end
      
      def peek_token(offset = 1)
        @tokens[@position + offset]
      end
      
      def at_end?
        current_token.kind == :eof
      end
      
      # Advance WITHOUT collecting trivia
      def advance_raw
        token = current_token
        @position += 1 unless at_end?
        token
      end
      
      # Collect trivia (whitespace, comments) as string
      def collect_trivia_string
        result = ""
        
        while current_token && Token.trivia?(current_token.kind)
          result << current_token.lexeme
          advance_raw
        end
        
        result
      end
      
      # Expect specific token kind
      def expect(kind)
        unless current_token.kind == kind
          raise ParseError, 
            "Expected #{kind}, got #{current_token.kind} at #{current_token.line}:#{current_token.column}"
        end
        
        advance_raw
      end
      
      # Expect identifier
      def expect_identifier
        unless current_token.kind == :identifier
          raise ParseError, 
            "Expected identifier, got #{current_token.kind} at #{current_token.line}:#{current_token.column}"
        end
        
        advance_raw
      end
    end
  end
end
```

**Run Test:**
```bash
ruby test/parsers/test_base_parser.rb
# Expected: 6 tests, ~10 assertions, 0 failures
```

#### Step 3.2: Expression Parser (TDD)

**Test First:**
```ruby
# test/parsers/test_expression_parser.rb
require_relative "../test_helper"

class TestExpressionParser < Minitest::Test
  def parse_expression(source)
    lexer = CppAst::Lexer.new(source)
    parser = CppAst::Parsers::ExpressionParser.new(lexer)
    expr, trailing = parser.parse_expression
    [expr, trailing]
  end
  
  def test_parse_identifier
    expr, trailing = parse_expression("foo")
    
    assert_instance_of CppAst::Nodes::Identifier, expr
    assert_equal "foo", expr.name
    assert_equal "", trailing
  end
  
  def test_parse_identifier_with_trailing
    expr, trailing = parse_expression("foo ")
    
    assert_equal "foo", expr.name
    assert_equal " ", trailing
  end
  
  def test_parse_number
    expr, trailing = parse_expression("42")
    
    assert_instance_of CppAst::Nodes::NumberLiteral, expr
    assert_equal "42", expr.value
  end
  
  def test_parse_binary_expression_no_spaces
    expr, _ = parse_expression("x+42")
    
    assert_instance_of CppAst::Nodes::BinaryExpression, expr
    assert_equal "x", expr.left.name
    assert_equal "+", expr.operator
    assert_equal "42", expr.right.value
    assert_equal "", expr.operator_prefix
    assert_equal "", expr.operator_suffix
  end
  
  def test_parse_binary_expression_with_spaces
    expr, _ = parse_expression("x + 42")
    
    assert_equal " ", expr.operator_prefix
    assert_equal " ", expr.operator_suffix
  end
  
  def test_binary_expression_roundtrip
    source = "x + 42"
    expr, trailing = parse_expression(source)
    
    assert_equal source, expr.to_source + trailing
  end
end
```

**Implementation:**
```ruby
# lib/cpp_ast/parsers/expression_parser.rb
module CppAst
  module Parsers
    class ExpressionParser < BaseParser
      # Parse expression and return (expr, trailing)
      def parse_expression
        parse_binary_expression(0)
      end
      
      private
      
      # Operator precedence table
      OPERATOR_INFO = {
        equals: { precedence: 1, right_assoc: true },
        plus: { precedence: 10, right_assoc: false },
        minus: { precedence: 10, right_assoc: false },
        asterisk: { precedence: 20, right_assoc: false },
        slash: { precedence: 20, right_assoc: false },
      }.freeze
      
      def operator_info(kind)
        OPERATOR_INFO[kind]
      end
      
      # Pratt parser for binary expressions
      def parse_binary_expression(min_precedence)
        left, left_trailing = parse_primary
        
        loop do
          # Collect trivia BEFORE operator
          operator_prefix = left_trailing + collect_trivia_string
          
          # Check if current token is operator
          info = operator_info(current_token.kind)
          break unless info && info[:precedence] >= min_precedence
          
          # Consume operator
          operator = current_token.lexeme
          advance_raw
          
          # Collect trivia AFTER operator
          operator_suffix = collect_trivia_string
          
          # Parse right side with higher precedence
          next_precedence = info[:right_assoc] ? info[:precedence] : info[:precedence] + 1
          right, right_trailing = parse_binary_expression(next_precedence)
          
          # Build binary expression
          left = Nodes::BinaryExpression.new(
            left: left,
            operator: operator,
            right: right,
            operator_prefix: operator_prefix,
            operator_suffix: operator_suffix
          )
          left_trailing = right_trailing
        end
        
        [left, left_trailing]
      end
      
      # Parse primary expression (identifier, number, etc)
      def parse_primary
        case current_token.kind
        when :identifier
          name = current_token.lexeme
          advance_raw
          trailing = collect_trivia_string
          [Nodes::Identifier.new(name: name), trailing]
          
        when :number
          value = current_token.lexeme
          advance_raw
          trailing = collect_trivia_string
          [Nodes::NumberLiteral.new(value: value), trailing]
          
        else
          raise ParseError, "Unexpected token: #{current_token.kind}"
        end
      end
    end
  end
end
```

**Run Test:**
```bash
ruby test/parsers/test_expression_parser.rb
# Expected: 6+ tests, ~15 assertions, 0 failures
```

#### Step 3.3: Statement Parser (TDD)

**Test First:**
```ruby
# test/parsers/test_statement_parser.rb
require_relative "../test_helper"

class TestStatementParser < Minitest::Test
  def parse_statement(source, leading_trivia = "")
    lexer = CppAst::Lexer.new(source)
    parser = CppAst::Parsers::StatementParser.new(lexer)
    stmt, trailing = parser.parse_statement(leading_trivia)
    [stmt, trailing]
  end
  
  def test_parse_expression_statement
    stmt, _ = parse_statement("foo;")
    
    assert_instance_of CppAst::Nodes::ExpressionStatement, stmt
    assert_equal "foo", stmt.expression.name
  end
  
  def test_parse_expression_statement_with_leading_trivia
    stmt, _ = parse_statement("foo;", "  ")
    
    assert_equal "  ", stmt.leading_trivia
    assert_equal "  foo;", stmt.to_source
  end
  
  def test_parse_return_statement
    stmt, _ = parse_statement("return 42;")
    
    assert_instance_of CppAst::Nodes::ReturnStatement, stmt
    assert_equal "42", stmt.expression.value
  end
  
  def test_statement_roundtrip
    source = "  return 42;\n"
    stmt, trailing = parse_statement(source[2..-2], "  ")
    
    assert_equal source, stmt.to_source + trailing
  end
end
```

**Implementation:**
```ruby
# lib/cpp_ast/parsers/statement_parser.rb
module CppAst
  module Parsers
    class StatementParser < ExpressionParser
      # Parse statement with leading_trivia
      # Returns (stmt, trailing)
      def parse_statement(leading_trivia = "")
        # Check for return statement
        if current_token.kind == :identifier && current_token.lexeme == "return"
          return parse_return_statement(leading_trivia)
        end
        
        # Otherwise, expression statement
        parse_expression_statement(leading_trivia)
      end
      
      private
      
      def parse_expression_statement(leading_trivia)
        expr, expr_trailing = parse_expression
        
        # Consume semicolon with any trivia before it
        semicolon_prefix = expr_trailing + collect_trivia_string
        expect(:semicolon)
        
        # Collect trailing after semicolon
        trailing = collect_trivia_string
        
        stmt = Nodes::ExpressionStatement.new(
          leading_trivia: leading_trivia,
          expression: expr
        )
        
        [stmt, trailing]
      end
      
      def parse_return_statement(leading_trivia)
        # Consume 'return' keyword
        advance_raw  # 'return'
        
        # Collect trivia after 'return'
        keyword_suffix = collect_trivia_string
        
        # Parse expression
        expr, expr_trailing = parse_expression
        
        # Consume semicolon
        semicolon_prefix = expr_trailing + collect_trivia_string
        expect(:semicolon)
        
        # Collect trailing
        trailing = collect_trivia_string
        
        stmt = Nodes::ReturnStatement.new(
          leading_trivia: leading_trivia,
          expression: expr,
          keyword_suffix: keyword_suffix
        )
        
        [stmt, trailing]
      end
    end
  end
end
```

**Run Test:**
```bash
ruby test/parsers/test_statement_parser.rb
# Expected: 4+ tests, ~8 assertions, 0 failures
```

#### Step 3.4: Program Parser (TDD)

**Test First:**
```ruby
# test/parsers/test_program_parser.rb
require_relative "../test_helper"

class TestProgramParser < Minitest::Test
  def parse_program(source)
    lexer = CppAst::Lexer.new(source)
    parser = CppAst::Parsers::ProgramParser.new(lexer)
    parser.parse
  end
  
  def test_parse_empty_program
    program = parse_program("")
    
    assert_equal 0, program.statements.size
  end
  
  def test_parse_single_statement
    source = "x = 42;\n"
    program = parse_program(source)
    
    assert_equal 1, program.statements.size
    assert_instance_of CppAst::Nodes::ExpressionStatement, program.statements[0]
  end
  
  def test_parse_multiple_statements
    source = "x = 1;\ny = 2;\n"
    program = parse_program(source)
    
    assert_equal 2, program.statements.size
  end
  
  def test_program_roundtrip
    source = "x = 42;\nreturn x;\n"
    program = parse_program(source)
    
    assert_equal source, program.to_source
  end
  
  def test_program_preserves_blank_lines
    source = "x = 1;\n\ny = 2;\n"
    program = parse_program(source)
    
    assert_equal source, program.to_source
  end
end
```

**Implementation:**
```ruby
# lib/cpp_ast/parsers/program_parser.rb
module CppAst
  module Parsers
    class ProgramParser < StatementParser
      # Parse entire program
      def parse
        statements = []
        statement_trailings = []
        
        # Collect leading trivia
        leading = collect_trivia_string
        
        until at_end?
          stmt, trailing = parse_statement(leading)
          statements << stmt
          statement_trailings << trailing
          
          # Next statement starts immediately (no leading)
          leading = ""
        end
        
        Nodes::Program.new(
          statements: statements,
          statement_trailings: statement_trailings
        )
      end
    end
  end
end
```

**Run Test:**
```bash
ruby test/parsers/test_program_parser.rb
# Expected: 5 tests, ~8 assertions, 0 failures
```

---

### Phase 4: Integration & Roundtrip Tests (2-3 часа)

#### Step 4.1: Roundtrip Tests

**Test First:**
```ruby
# test/integration/test_roundtrip.rb
require_relative "../test_helper"

class TestRoundtrip < Minitest::Test
  def test_simple_assignment
    assert_roundtrip "x = 42;\n"
  end
  
  def test_multiple_statements
    assert_roundtrip "x = 1;\ny = 2;\n"
  end
  
  def test_with_indentation
    assert_roundtrip "  x = 42;\n  y = 100;\n"
  end
  
  def test_with_blank_lines
    assert_roundtrip "x = 1;\n\ny = 2;\n"
  end
  
  def test_with_comments
    assert_roundtrip "x = 42; // comment\n"
  end
  
  def test_complex_expression
    assert_roundtrip "result = x + y * 2;\n"
  end
  
  def test_return_statement
    assert_roundtrip "return x + 42;\n"
  end
end
```

**Run Test:**
```bash
ruby test/integration/test_roundtrip.rb
# Expected: ALL tests PASS (100% roundtrip)
```

---

### Phase 5: Public API (30 минут)

#### Step 5.1: Create Main API

```ruby
# lib/cpp_ast.rb
require_relative "cpp_ast/lexer/token"
require_relative "cpp_ast/lexer/lexer"
require_relative "cpp_ast/nodes/base"
require_relative "cpp_ast/nodes/expressions"
require_relative "cpp_ast/nodes/statements"
require_relative "cpp_ast/parsers/base_parser"
require_relative "cpp_ast/parsers/expression_parser"
require_relative "cpp_ast/parsers/statement_parser"
require_relative "cpp_ast/parsers/program_parser"

module CppAst
  class << self
    # Public API: Parse source into AST
    def parse(source)
      lexer = Lexer.new(source)
      parser = Parsers::ProgramParser.new(lexer)
      parser.parse
    end
  end
end
```

#### Step 5.2: Create README

```markdown
# C++ AST Parser (V3)

Pure Ruby C++ parser with **100% roundtrip accuracy**.

## Features

✅ **Perfect whitespace preservation**: `source -> AST -> to_source == source`
✅ **Clean architecture**: Separate lexer, parser, nodes layers
✅ **TDD from day 1**: Comprehensive test coverage
✅ **Ruby way**: Idiomatic, simple, maintainable

## Installation

```bash
gem install cpp_ast
```

## Usage

```ruby
require "cpp_ast"

source = "x = 42;\n"
program = CppAst.parse(source)

puts program.to_source  # => "x = 42;\n"
```

## Architecture

```
cpp_ast/
├── lexer/      # Tokenization
├── nodes/      # AST nodes (pure data)
├── parsers/    # Parsing logic
└── rewriters/  # AST manipulation
```

## Running Tests

```bash
rake test
```

## License

MIT
```

---

## 6. Контрольные точки

### Checkpoint 1: Lexer (2-3 hours)
**Goal:** Tokenize basic C++ constructs
- ✅ Token class with trivia support
- ✅ Lexer with identifiers, numbers, operators
- ✅ Whitespace and comment handling
- ✅ All lexer tests passing

**Success Criteria:**
```bash
ruby test/lexer/*.rb
# Expected: ALL PASS
```

### Checkpoint 2: Nodes (1-2 hours)
**Goal:** Define AST node structure
- ✅ Base node classes (Node, Expression, Statement)
- ✅ Expression nodes (Identifier, NumberLiteral, BinaryExpression)
- ✅ Statement nodes (ExpressionStatement, ReturnStatement)
- ✅ Program node
- ✅ All node tests passing

**Success Criteria:**
```bash
ruby test/nodes/*.rb
# Expected: ALL PASS
```

### Checkpoint 3: Parsers (4-6 hours)
**Goal:** Parse source into AST
- ✅ BaseParser with trivia collection
- ✅ ExpressionParser with binary expression support
- ✅ StatementParser
- ✅ ProgramParser
- ✅ All parser tests passing

**Success Criteria:**
```bash
ruby test/parsers/*.rb
# Expected: ALL PASS
```

### Checkpoint 4: Integration (2-3 hours)
**Goal:** 100% roundtrip accuracy
- ✅ Roundtrip tests for all constructs
- ✅ Fixture files from real projects
- ✅ Edge cases covered

**Success Criteria:**
```bash
ruby test/integration/test_roundtrip.rb
# Expected: 100% roundtrip accuracy
```

### Checkpoint 5: Extension Phase (Iterative)
**Goal:** Add more C++ features

Each iteration follows the same pattern:
1. Write test for new feature
2. Implement in nodes
3. Implement in parser
4. Verify roundtrip
5. Commit

**Features to add (in order):**
- [ ] Parenthesized expressions
- [ ] Unary expressions
- [ ] Assignment operators (+=, -=, etc)
- [ ] Member access (., ->)
- [ ] Function calls
- [ ] If/else statements
- [ ] While/for loops
- [ ] Function definitions
- [ ] Class definitions

---

## 7. Команды для выполнения

### Setup Commands

```bash
# 1. Create project
cd /home/jenya/workspaces/experimental
mkdir cpp_ast_v3
cd cpp_ast_v3

# 2. Create structure
mkdir -p lib/cpp_ast/{lexer/helpers,nodes,parsers,rewriters}
mkdir -p test/{lexer,nodes,parsers,integration,fixtures}

# 3. Install dependencies
cat > Gemfile << 'EOF'
source "https://rubygems.org"
gem "minitest", "~> 5.0"
gem "rake", "~> 13.0"
EOF

bundle install

# 4. Run tests
rake test

# Or run specific test file
ruby test/lexer/test_token.rb
```

### Development Workflow

```bash
# 1. Write test (RED)
ruby test/nodes/test_expression_nodes.rb
# => FAIL

# 2. Implement feature (GREEN)
# Edit lib/cpp_ast/nodes/expressions.rb

ruby test/nodes/test_expression_nodes.rb
# => PASS

# 3. Refactor if needed
# Clean up code, run tests again

# 4. Commit
git add .
git commit -m "Add BinaryExpression node with trivia support"
```

---

## 8. Ключевые правила для AI агента

### Rule 1: ALWAYS TDD
```
NEVER write implementation before test
```

### Rule 2: ONE feature at a time
```
Finish ONE feature completely before moving to next
```

### Rule 3: Keep files small
```
Max 400 lines per file
Split large files into modules
```

### Rule 4: Test trivia ALWAYS
```ruby
def test_preserves_whitespace
  source = "x + 42"
  expr, _ = parse_expression(source)
  assert_equal source, expr.to_source
end
```

### Rule 5: Document design decisions
```ruby
# WHY: Parent owns spacing between children
# This prevents duplication when composing nodes
class Program
  attr_accessor :statements, :statement_trailings
end
```

---

## 9. Expected Timeline

| Phase | Time | Description |
|-------|------|-------------|
| Phase 0 | 30 min | Setup project structure |
| Phase 1 | 2-3 hours | Lexer implementation |
| Phase 2 | 1-2 hours | Node definitions |
| Phase 3 | 4-6 hours | Parser implementation |
| Phase 4 | 2-3 hours | Integration tests |
| Phase 5 | 30 min | Public API & docs |
| **Total** | **10-15 hours** | **MVP with 100% roundtrip** |

### Extension Timeline (Optional)

| Feature | Time | Priority |
|---------|------|----------|
| Parentheses | 1 hour | High |
| Unary operators | 1 hour | High |
| Function calls | 2 hours | High |
| If/else | 2 hours | Medium |
| Loops | 2 hours | Medium |
| Functions | 3 hours | Medium |
| Classes | 4 hours | Low |

---

## 10. Success Metrics

### Phase 1-5 (MVP)
- ✅ 100% test coverage
- ✅ 100% roundtrip accuracy for supported constructs
- ✅ All files < 400 lines
- ✅ Zero circular dependencies
- ✅ Clear module boundaries

### Extension Phase
- ✅ Each new feature: test → implement → roundtrip → commit
- ✅ No regressions (all previous tests still pass)
- ✅ Documentation updated

---

## 11. Troubleshooting Guide

### Problem: Trivia disappearing

**Symptom:**
```ruby
source = "x + 42"
program = parse(source)
program.to_source  # => "x+42" (spaces gone!)
```

**Solution:**
Check that parser returns trailing:
```ruby
def parse_expression
  expr = create_expr
  trailing = collect_trivia_string  # ← Must collect!
  [expr, trailing]  # ← Must return!
end
```

### Problem: Trivia duplication

**Symptom:**
```ruby
program.to_source  # => "x  +  42" (double spaces!)
```

**Solution:**
Parent is adding trivia that child already has. Remove trivia from child:
```ruby
# BAD
class BinaryExpression
  def to_source
    "#{left.to_source} #{operator} #{right.to_source}"  # ← Adds spaces!
  end
end

# GOOD
class BinaryExpression
  def to_source
    "#{left.to_source}#{operator_prefix}#{operator}#{operator_suffix}#{right.to_source}"
  end
end
```

### Problem: Tests slow

**Symptom:**
Test suite takes > 10 seconds

**Solution:**
1. Use unit tests (mock dependencies)
2. Avoid parsing in every test (use fixtures)
3. Run specific test files during development

```bash
# Instead of
rake test  # runs ALL tests

# Use
ruby test/nodes/test_expression_nodes.rb  # fast!
```

---

## 12. Final Checklist

Before declaring Phase 1-5 complete:

- [ ] All tests passing
- [ ] 100% roundtrip for simple programs
- [ ] No files > 400 lines
- [ ] README.md written
- [ ] All code follows Ruby style guide
- [ ] No rubocop warnings
- [ ] Git repo initialized with clear commits

---

## 13. Next Steps After MVP

1. **Add more operators**
   - Comparison (<, >, ==, !=)
   - Logical (&&, ||, !)
   - Bitwise (&, |, ^, ~)

2. **Add more statements**
   - If/else
   - While/for loops
   - Switch/case

3. **Add declarations**
   - Variable declarations
   - Function declarations
   - Class declarations

4. **Add rewriter support**
   - Find nodes
   - Replace nodes
   - Insert/delete nodes

5. **Add real-world testing**
   - Parse files from gtk-gl-cpp-2025 project
   - Fix edge cases
   - Optimize performance

---

**GOOD LUCK! Remember: TDD, Small Steps, Always Roundtrip!** 🚀


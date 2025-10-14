# Дорожная карта: Trivia в токенах (Уровень 1)

## ✅ СТАТУС: ЗАВЕРШЕНО (14 января 2025)

## Цель

Перенести хранение trivia из парсера в сами токены для соответствия принципам lossless CST.

## Текущее состояние vs Целевое

### БЫЛО (Текущее)
```ruby
# Token не знает о trivia
class Token
  attr_reader :kind, :lexeme, :line, :column
end

# Лексер создаёт trivia как отдельные токены
tokens = [
  Token(:identifier, "x"),
  Token(:whitespace, " "),
  Token(:equals, "="),
  Token(:whitespace, " "),
  Token(:number, "42")
]

# Парсер собирает trivia вручную
def parse_statement(leading_trivia)
  # ...
  trailing = collect_trivia_string
  [stmt, trailing]
end
```

### БУДЕТ (Целевое)
```ruby
# Token знает свои trivia
class Token
  attr_reader :kind, :lexeme, :line, :column
  attr_accessor :leading_trivia, :trailing_trivia
end

# Лексер присваивает trivia токенам
tokens = [
  Token(:identifier, "x", leading: "", trailing: " "),
  Token(:equals, "=", leading: "", trailing: " "),
  Token(:number, "42", leading: "", trailing: "")
]

# Парсер использует token.leading_trivia
def parse_statement
  leading = current_token.leading_trivia
  # ...
  [stmt, trailing]
end
```

## Подробный план реализации

### Шаг 1: Расширить Token (30 мин)

**Файл**: `lib/cpp_ast/lexer/token.rb`

```ruby
class Token
  attr_reader :kind, :lexeme, :line, :column
  attr_accessor :leading_trivia, :trailing_trivia  # NEW
  
  TRIVIA_KINDS = [:whitespace, :comment, :newline, :preprocessor, :attribute].freeze
  
  def initialize(kind:, lexeme:, line:, column:, leading_trivia: "", trailing_trivia: "")
    @kind = kind
    @lexeme = lexeme
    @line = line
    @column = column
    @leading_trivia = leading_trivia  # NEW
    @trailing_trivia = trailing_trivia  # NEW
  end
  
  # ... rest unchanged
end
```

**Тесты**: `test/lexer/token_test.rb`
```ruby
def test_token_with_leading_trivia
  token = Token.new(kind: :identifier, lexeme: "foo", line: 1, column: 2,
                    leading_trivia: "  ")
  assert_equal "  ", token.leading_trivia
end

def test_token_with_trailing_trivia
  token = Token.new(kind: :identifier, lexeme: "foo", line: 1, column: 2,
                    trailing_trivia: " // comment\n")
  assert_equal " // comment\n", token.trailing_trivia
end
```

### Шаг 2: Изменить Lexer - алгоритм сборки trivia (2-3 часа)

**Файл**: `lib/cpp_ast/lexer/lexer.rb`

**Новый алгоритм**:
1. Собирать leading trivia перед каждым non-trivia токеном
2. Создать non-trivia токен с leading
3. Собирать trailing trivia после токена
4. Присвоить trailing текущему токену

**Новый метод**:
```ruby
def tokenize
  tokens = []
  
  until at_end?
    # Собрать leading trivia
    leading = collect_trivia_as_string
    
    # Сканировать non-trivia токен
    token = scan_non_trivia_token
    break if token.nil?  # EOF
    
    # Присвоить leading trivia
    token.leading_trivia = leading
    
    # Собрать trailing trivia
    trailing = collect_trivia_as_string
    token.trailing_trivia = trailing
    
    tokens << token
  end
  
  # EOF token с leading trivia (trailing всегда пусто)
  eof_leading = collect_trivia_as_string
  tokens << Token.new(kind: :eof, lexeme: "", line: @line, column: @column,
                      leading_trivia: eof_leading)
  
  tokens
end

private

def collect_trivia_as_string
  result = "".dup
  
  while !at_end? && trivia_ahead?
    token = scan_trivia_token
    result << token.lexeme if token
  end
  
  result
end

def trivia_ahead?
  char = current_char
  return false if char.nil?
  
  char =~ /\s/ ||  # whitespace or newline
  (char == '/' && (peek == '/' || peek == '*')) ||  # comment
  (char == '#')  # preprocessor
end

def scan_trivia_token
  # Существующая логика для whitespace/comment/newline/preprocessor
  # Возвращает Token, но он не добавляется в массив - только lexeme используется
end

def scan_non_trivia_token
  # Существующая логика для identifier/number/operators
  # НО без trivia - они уже собраны
end
```

**Важно**: Нужно разделить `scan_token` на `scan_trivia_token` и `scan_non_trivia_token`

**Тесты**: `test/lexer/lexer_basic_test.rb`
```ruby
def test_token_has_leading_trivia
  lexer = Lexer.new("  x")
  tokens = lexer.tokenize
  
  assert_equal :identifier, tokens[0].kind
  assert_equal "  ", tokens[0].leading_trivia
end

def test_token_has_trailing_trivia
  lexer = Lexer.new("x // comment\n")
  tokens = lexer.tokenize
  
  assert_equal :identifier, tokens[0].kind
  assert_equal " // comment\n", tokens[0].trailing_trivia
end

def test_multiple_tokens_with_trivia
  lexer = Lexer.new("x = 42;\n")
  tokens = lexer.tokenize
  
  assert_equal "x", tokens[0].lexeme
  assert_equal "", tokens[0].leading_trivia
  assert_equal " ", tokens[0].trailing_trivia
  
  assert_equal "=", tokens[1].lexeme
  assert_equal "", tokens[1].leading_trivia
  assert_equal " ", tokens[1].trailing_trivia
  
  assert_equal "42", tokens[2].lexeme
  assert_equal "", tokens[2].leading_trivia
  assert_equal "", tokens[2].trailing_trivia
end
```

### Шаг 3: Адаптировать парсер (1-2 часа)

**Файл**: `lib/cpp_ast/parsers/base_parser.rb`

**Старый способ**:
```ruby
def collect_trivia_string
  result = "".dup
  while current_token && Token.trivia?(current_token.kind)
    result << current_token.lexeme
    advance_raw
  end
  result
end
```

**Новый способ**:
```ruby
# Удалить collect_trivia_string - больше не нужен!

# Вместо него:
def current_leading_trivia
  current_token.leading_trivia
end

def consume_token_get_trailing
  token = current_token
  advance_raw
  token.trailing_trivia
end
```

**Файл**: `lib/cpp_ast/parsers/program_parser.rb`

**Старый способ**:
```ruby
def parse
  statements = []
  statement_trailings = []
  
  leading = collect_trivia_string  # СТАРОЕ
  
  until at_end?
    stmt, trailing = parse_statement(leading)
    statements << stmt
    statement_trailings << trailing
    leading = ""
  end
  
  # ...
end
```

**Новый способ**:
```ruby
def parse
  statements = []
  statement_trailings = []
  
  until at_end?
    # leading берётся из текущего токена
    stmt, trailing = parse_statement
    statements << stmt
    statement_trailings << trailing
  end
  
  # Trailing trivia в конце - это leading_trivia EOF токена
  final_trailing = current_token.leading_trivia if current_token.kind == :eof
  
  # ...
end
```

**Файл**: `lib/cpp_ast/parsers/statement_parser.rb`

Изменить сигнатуры:
```ruby
# СТАРОЕ:
def parse_statement(leading_trivia)
  # ...
end

# НОВОЕ:
def parse_statement
  leading_trivia = current_leading_trivia  # Берём из токена
  # ... остальное без изменений
end
```

**Тесты**: Существующие тесты должны продолжать работать без изменений!

### Шаг 4: Упростить узлы (опционально, 1-2 часа)

Это опциональный шаг для будущего. Пока оставляем узлы как есть:
- Узлы продолжают принимать `leading_trivia` как параметр
- Парсер извлекает trivia из токенов и передаёт в узлы

**В будущем** можно упростить:
```ruby
# Вместо:
Nodes::ExpressionStatement.new(
  leading_trivia: leading,
  expression: expr
)

# Можно:
Nodes::ExpressionStatement.new(
  first_token: token,  # Token с leading_trivia внутри
  expression: expr
)
```

Но это большой рефакторинг, отложим на потом.

### Шаг 5: Регрессионное тестирование (30 мин)

Запустить все тесты:
```bash
rake test
```

Ожидаемый результат: **0 failures** (все 481 теста проходят)

Если есть failures:
1. Проверить что trivia правильно собраны в лексере
2. Проверить что парсер правильно использует token trivia
3. Проверить to_source - должен остаться без изменений

## Оценка сложности

| Шаг | Сложность | Время | Риски |
|-----|-----------|-------|-------|
| 1. Token | Низкая | 30 мин | Нет |
| 2. Lexer | Высокая | 2-3 часа | Может сломать tokenize |
| 3. Parser | Средняя | 1-2 часа | Может сломать parse |
| 4. Nodes | Средняя | 1-2 часа | Большой рефакторинг |
| 5. Tests | Низкая | 30 мин | Нет |
| **ИТОГО** | | **4-6 часов** | |

## Преимущества после реализации

✅ **Архитектурное соответствие**: Token знает свои trivia (как в эталоне)  
✅ **Упрощение парсера**: Не нужно вручную собирать trivia  
✅ **Самодостаточность токенов**: Token содержит всю информацию  
✅ **Подготовка к редактированию**: Проще создавать/изменять токены  
✅ **Чистота кода**: Меньше передачи параметров leading_trivia  

## Риски и митигация

### Риск 1: Сломать tokenize
**Митигация**: 
- Писать тесты для лексера перед изменениями
- Тестировать edge cases (комментарии, preprocessor)
- Откатиться через git если что-то сломается

### Риск 2: Сломать roundtrip
**Митигация**:
- Запускать roundtrip тесты после каждого шага
- Использовать `scripts/verify_roundtrip.rb` на реальных файлах
- Сравнивать вывод до/после изменений

### Риск 3: Производительность
**Митигация**:
- Профилировать до и после (`scripts/profile_parser.rb`)
- Если замедление > 20%, оптимизировать collect_trivia_as_string

## Порядок внедрения (incremental)

### Вариант A: Всё сразу (рискованно)
1. Сделать все изменения
2. Прогнать тесты
3. Фиксить до зелёного

**Плюс**: Быстро  
**Минус**: Если сломается - непонятно где

### Вариант B: Поэтапно (рекомендуется)

#### Итерация 1: Token + базовый тест
1. Добавить поля в Token
2. Написать тест для Token с trivia
3. Commit

#### Итерация 2: Lexer изменения
1. Реализовать collect_trivia_as_string
2. Реализовать новый tokenize (заполнять trivia)
3. Написать тесты для лексера
4. Прогнать тесты лексера → зелёный
5. Commit

#### Итерация 3: Parser адаптация
1. Адаптировать base_parser (использовать token trivia)
2. Адаптировать program_parser
3. Адаптировать statement_parser сигнатуры
4. Прогнать ВСЕ тесты → зелёный
5. Commit

#### Итерация 4: Проверка roundtrip
1. Запустить `scripts/verify_roundtrip.rb`
2. Проверить на реальных файлах (gtk_gl_sample.cpp)
3. Если всё ок → Commit

## Чеклист выполнения

- [x] Шаг 1: Расширить Token ✅
  - [x] Добавить leading_trivia, trailing_trivia поля
  - [x] Обновить initialize
  - [x] Написать тесты
  - [x] Commit

- [x] Шаг 2: Изменить Lexer ✅
  - [x] Создать collect_trivia_as_string
  - [x] Создать trivia_ahead?
  - [x] Переписать tokenize (присваивать trivia)
  - [x] Написать тесты для лексера
  - [x] Прогнать тесты лексера → зелёный
  - [x] Commit

- [x] Шаг 3: Адаптировать Parser ✅
  - [x] Изменить base_parser (current_leading_trivia)
  - [x] Изменить program_parser (убрать collect_trivia_string)
  - [x] Изменить statement_parser (убрать leading_trivia параметр)
  - [x] Прогнать ВСЕ тесты
  - [x] Commit

- [x] Шаг 4: Регрессионное тестирование ✅
  - [x] rake test → 653 tests, 0 failures
  - [x] scripts/verify_roundtrip.rb → success
  - [x] Проверить на gtk_gl_sample.cpp
  - [x] Commit

- [x] Шаг 5: Документация ✅
  - [x] Обновить README.md (упомянуть trivia в токенах)
  - [x] Создать TRIVIA_COMPLETION_REPORT.md
  - [x] Commit

## Результаты реализации

**Дата завершения**: 14 января 2025  
**Тесты**: 653 runs, 863 assertions, 0 failures ✅  
**CST Compliance**: 10/10 ✅  
**Performance**: 4-18 мс на 75-114 строк ✅

См. подробный отчёт: `TRIVIA_COMPLETION_REPORT.md`

## Альтернативы

### Альтернатива 1: Оставить как есть
**Плюсы**: Работает, ничего не ломается  
**Минусы**: Архитектура не соответствует эталону

### Альтернатива 2: Сразу перейти к Уровню 2 (байтовые диапазоны)
**Плюсы**: Финальная архитектура сразу  
**Минусы**: Слишком сложно, высокий риск

**Рекомендация**: Уровень 1 - оптимальный баланс пользы и риска

## Следующие шаги после реализации

1. Оценить необходимость Уровня 2 (байтовые диапазоны)
2. Начать работу над rewriter-ами
3. Добавить больше функций (concepts, modules, coroutines)
4. Оптимизация производительности


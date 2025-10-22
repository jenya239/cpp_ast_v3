# CodeRabbit Examples для cpp_ast_v3

## Конкретные примеры проблем и их решений

### 1. Проблемы с парсингом

#### ❌ ПЛОХО: Некорректная обработка токенов
```ruby
def parse_expression
  case current.type
  when :IDENTIFIER
    consume(:IDENTIFIER)
    # Проблема: не создается AST узел
  end
end
```

#### ✅ ХОРОШО: Корректная обработка
```ruby
def parse_expression
  case current.type
  when :IDENTIFIER
    name = current.value
    consume(:IDENTIFIER)
    Aurora::AST::VarRef.new(name: name)
  end
end
```

### 2. Проблемы с генерацией кода

#### ❌ ПЛОХО: Неэффективная конкатенация
```ruby
def generate_class(klass)
  result = "class #{klass.name} {\n"
  klass.methods.each do |method|
    result += "  " + method.to_cpp + "\n"
  end
  result + "};\n"
end
```

#### ✅ ХОРОШО: Эффективная генерация
```ruby
def generate_class(klass)
  methods = klass.methods.map { |m| "  " + m.to_cpp }.join("\n")
  "class #{klass.name} {\n#{methods}\n};\n"
end
```

### 3. Проблемы с кэшированием

#### ❌ ПЛОХО: Некорректный cache key
```ruby
def parse_binary_expression(left, min_precedence = 0)
  cache_key = "#{@pos}_binary_#{min_precedence}"
  return @cache[cache_key] if @cache[cache_key]
  # Проблема: left не учитывается в cache key
end
```

#### ✅ ХОРОШО: Без кэширования или корректный key
```ruby
def parse_binary_expression(left, min_precedence = 0)
  # Без кэширования, так как left сложно сериализовать
  while current.type == :OPERATOR && precedence(current.value) >= min_precedence
    # ... логика парсинга
  end
end
```

### 4. Проблемы с обработкой ошибок

#### ❌ ПЛОХО: Неинформативные ошибки
```ruby
def parse_function
  consume(:FN)
  # Может упасть без объяснения
  name = consume(:IDENTIFIER).value
end
```

#### ✅ ХОРОШО: Информативные ошибки
```ruby
def parse_function
  consume(:FN)
  if current.type != :IDENTIFIER
    raise ParseError.new(
      message: "Expected function name, got #{current.type}",
      location: current.location,
      suggestion: "Function names must be identifiers"
    )
  end
  name = consume(:IDENTIFIER).value
end
```

### 5. Проблемы с тестированием

#### ❌ ПЛОХО: Неполные тесты
```ruby
def test_parsing
  ast = parser.parse("fn test() = 42")
  assert ast.is_a?(Aurora::AST::Program)
end
```

#### ✅ ХОРОШО: Полные тесты
```ruby
def test_parsing
  ast = parser.parse("fn test() = 42")
  assert_equal Aurora::AST::Program, ast.class
  assert_equal 1, ast.declarations.length
  
  func = ast.declarations.first
  assert_equal "test", func.name
  assert_equal 0, func.params.length
  assert_equal 42, func.body.value
end
```

## Специфические паттерны для проекта

### 1. AST Construction
```ruby
# ✅ ХОРОШО: Используй именованные параметры
Aurora::AST::FuncDecl.new(
  name: "test",
  params: [],
  return_type: Aurora::AST::PrimType.new(name: "i32"),
  body: Aurora::AST::IntLit.new(value: 42)
)
```

### 2. Parser Error Recovery
```ruby
# ✅ ХОРОШО: Восстановление после ошибок
def parse_with_recovery
  errors = []
  begin
    parse_program
  rescue ParseError => e
    errors << e
    recover_to_next_declaration
    retry
  end
  errors
end
```

### 3. Code Generation
```ruby
# ✅ ХОРОШО: Используй StringBuilder для больших объемов
def generate_large_code(nodes)
  builder = StringBuilder.new
  nodes.each do |node|
    builder.append(node.to_cpp)
    builder.append("\n")
  end
  builder.to_s
end
```

## Чек-лист для CodeRabbit

### Критические проверки:
- [ ] Все AST узлы создаются корректно
- [ ] Генерируемый C++ код синтаксически корректен
- [ ] Парсер обрабатывает все токены
- [ ] Нет утечек памяти в циклах
- [ ] Cache keys включают все необходимые параметры

### Серьезные проверки:
- [ ] Производительность: нет O(n²) операций
- [ ] Обработка ошибок: информативные сообщения
- [ ] Тестирование: покрытие критических путей
- [ ] Архитектура: соблюдение SOLID принципов

### Средние проверки:
- [ ] Читаемость кода
- [ ] Документация API
- [ ] Стиль кода Ruby
- [ ] Комментарии для сложной логики

## Типичные проблемы в проекте

### 1. Парсинг
- Отсутствие создания AST узлов
- Некорректная обработка токенов
- Отсутствие error recovery

### 2. Генерация
- Неэффективная конкатенация строк
- Отсутствие форматирования
- Некорректная генерация C++

### 3. Производительность
- O(n²) алгоритмы
- Избыточные аллокации
- Некорректное кэширование

### 4. Тестирование
- Неполные тесты
- Отсутствие edge cases
- Нет интеграционных тестов

## Рекомендации по приоритизации

1. **Критические** - исправлять немедленно
2. **Серьезные** - исправлять в текущем PR
3. **Средние** - исправлять в следующих итерациях
4. **Минорные** - исправлять при рефакторинге

Помни: этот проект генерирует C++ код, который должен компилироваться. Корректность важнее всего!

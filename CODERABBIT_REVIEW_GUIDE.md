# CodeRabbit Review Guide для cpp_ast_v3

## Обзор проекта

**cpp_ast_v3** - это Ruby DSL для генерации и манипуляции C++ кода с полной поддержкой roundtrip, а также компилятор языка Aurora, который транслирует в C++20.

## Архитектура проекта

### Основные компоненты

1. **C++ AST DSL** (`lib/cpp_ast/`)
   - Генерация C++ кода из Ruby DSL
   - Поддержка классов, функций, пространств имен
   - Roundtrip: C++ → AST → C++

2. **Aurora Language** (`lib/aurora/`)
   - Современный статически типизированный язык
   - Компиляция в C++20 с использованием `std::variant`, `std::visit`
   - Поддержка sum types, pattern matching, generics

3. **CoreIR** (`lib/aurora/passes/`)
   - Промежуточное представление между Aurora AST и C++ AST
   - Оптимизации и трансформации

## Приоритеты ревью

### 🔴 КРИТИЧЕСКИЕ (Critical)
- **Безопасность памяти**: утечки, double-free, buffer overflows
- **Корректность парсинга**: некорректные AST, потеря данных
- **Критические баги**: segmentation faults, infinite loops
- **Некорректная генерация кода**: синтаксически неверный C++

### 🟠 СЕРЬЕЗНЫЕ (Major)
- **Производительность**: O(n²) алгоритмы, избыточные аллокации
- **Архитектурные проблемы**: tight coupling, нарушение SOLID
- **Обработка ошибок**: отсутствие error handling, неинформативные ошибки
- **Тестирование**: отсутствие тестов для критических путей

### 🟡 СРЕДНИЕ (Minor)
- **Читаемость кода**: сложные методы, отсутствие комментариев
- **Документация**: недокументированные API, устаревшие примеры
- **Стиль кода**: несоответствие Ruby conventions

## Детальные инструкции по компонентам

### 1. C++ AST DSL (`lib/cpp_ast/`)

#### Что ревьюить:
- **Корректность генерации**: проверяй, что генерируемый C++ компилируется
- **Roundtrip тесты**: C++ → AST → C++ должен сохранять семантику
- **Производительность**: избегай O(n²) операций в генераторах

#### Критические проверки:
```ruby
# ❌ ПЛОХО: Прямая конкатенация строк
result = ""
nodes.each { |node| result += node.to_cpp }

# ✅ ХОРОШО: StringBuilder или массив
result = nodes.map(&:to_cpp).join("\n")
```

#### Файлы для особого внимания:
- `lib/cpp_ast/builder/dsl_generator.rb` - основной генератор
- `lib/cpp_ast/builder/optimized_generator.rb` - оптимизированный генератор
- `test/builder/` - тесты генерации

### 2. Aurora Language (`lib/aurora/`)

#### Что ревьюить:
- **Парсинг**: корректность AST, обработка edge cases
- **Типизация**: проверка типов, inference
- **Генерация C++**: корректность трансляции в C++20

#### Критические проверки:
```ruby
# ❌ ПЛОХО: Отсутствие проверки типов
def generate_function(func)
  "int #{func.name}() { return #{func.body}; }"
end

# ✅ ХОРОШО: Проверка типов
def generate_function(func)
  return_type = map_aurora_type_to_cpp(func.return_type)
  "int #{func.name}() { return #{func.body}; }"
end
```

#### Файлы для особого внимания:
- `lib/aurora/parser/parser.rb` - основной парсер
- `lib/aurora/parser/optimized_parser.rb` - оптимизированный парсер
- `lib/aurora/passes/to_core.rb` - трансформация в CoreIR
- `lib/aurora/ast/nodes.rb` - AST узлы

### 3. Тестирование (`test/`)

#### Что ревьюить:
- **Покрытие**: все критические пути должны быть покрыты
- **Интеграционные тесты**: полные pipeline тесты
- **Производительность**: benchmark тесты

#### Критические проверки:
```ruby
# ❌ ПЛОХО: Отсутствие проверки результата
def test_parsing
  parser.parse("fn test() = 42")
end

# ✅ ХОРОШО: Полная проверка
def test_parsing
  ast = parser.parse("fn test() = 42")
  assert_equal 1, ast.declarations.length
  assert_equal "test", ast.declarations.first.name
end
```

### 4. Производительность

#### Что ревьюить:
- **Алгоритмическая сложность**: избегай O(n²) операций
- **Память**: минимизируй аллокации
- **Кэширование**: проверяй корректность cache keys

#### Критические проверки:
```ruby
# ❌ ПЛОХО: O(n²) конкатенация
def generate_large_code(nodes)
  result = ""
  nodes.each { |node| result += node.to_cpp }
  result
end

# ✅ ХОРОШО: O(n) генерация
def generate_large_code(nodes)
  nodes.map(&:to_cpp).join("\n")
end
```

### 5. Обработка ошибок

#### Что ревьюить:
- **Информативность**: ошибки должны быть понятными
- **Восстановление**: парсер должен продолжать работу после ошибок
- **Локализация**: точное указание места ошибки

#### Критические проверки:
```ruby
# ❌ ПЛОХО: Неинформативная ошибка
raise "Parse error"

# ✅ ХОРОШО: Детальная ошибка
raise ParseError.new(
  message: "Expected ')' but found '#{current_token.value}'",
  location: current_token.location,
  suggestion: "Did you mean to close the function parameter list?"
)
```

## Специфические паттерны для проекта

### 1. AST узлы
- Все узлы должны быть immutable
- Конструкторы с именованными параметрами
- Методы `to_cpp`, `to_source` для генерации

### 2. Парсеры
- Используй memoization для производительности
- Обрабатывай все токены корректно
- Предоставляй информативные ошибки

### 3. Генераторы
- Используй StringBuilder для больших объемов
- Поддерживай форматирование и отступы
- Обеспечивай корректность генерируемого C++

## Чек-лист для ревью

### Перед началом:
- [ ] Понимаешь архитектуру проекта
- [ ] Знаешь основные компоненты
- [ ] Понимаешь flow: Aurora → CoreIR → C++ AST → C++

### Во время ревью:
- [ ] Проверяешь корректность парсинга
- [ ] Проверяешь корректность генерации
- [ ] Ищешь проблемы производительности
- [ ] Проверяешь обработку ошибок
- [ ] Оцениваешь покрытие тестами

### После ревью:
- [ ] Все критические проблемы исправлены
- [ ] Тесты проходят
- [ ] Производительность не деградировала
- [ ] Документация обновлена

## Примеры хороших и плохих практик

### ❌ ПЛОХИЕ ПРАКТИКИ:

```ruby
# 1. Прямая манипуляция AST без проверок
def add_method_to_class(klass, method)
  klass.methods << method  # Может сломать инварианты
end

# 2. Отсутствие обработки ошибок
def parse_expression
  # Может упасть на неожиданном токене
  consume(:IDENTIFIER)
end

# 3. Неэффективная генерация
def generate_class(klass)
  result = "class #{klass.name} {\n"
  klass.methods.each do |method|
    result += "  " + method.to_cpp + "\n"  # O(n²)
  end
  result + "};\n"
end
```

### ✅ ХОРОШИЕ ПРАКТИКИ:

```ruby
# 1. Immutable AST с проверками
def add_method_to_class(klass, method)
  klass.with_methods(klass.methods + [method])
end

# 2. Обработка ошибок с контекстом
def parse_expression
  case current.type
  when :IDENTIFIER
    parse_identifier_expression
  else
    raise ParseError.new(
      message: "Expected expression, got #{current.type}",
      location: current.location
    )
  end
end

# 3. Эффективная генерация
def generate_class(klass)
  methods = klass.methods.map { |m| "  " + m.to_cpp }.join("\n")
  "class #{klass.name} {\n#{methods}\n};\n"
end
```

## Заключение

Этот проект требует особого внимания к:
1. **Корректности** - генерируемый код должен компилироваться
2. **Производительности** - большие объемы данных
3. **Тестированию** - сложная логика требует тщательного тестирования
4. **Документации** - API должен быть понятным для пользователей

Приоритизируй критические проблемы безопасности и корректности, затем производительность и архитектуру, и только потом стиль кода и документацию.

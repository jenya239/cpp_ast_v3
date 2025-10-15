# Политика управления Whitespace в cpp_ast

## Основные принципы

### Правило 1: Только trivia-поля
**to_source методы НЕ добавляют пробелов.** Все пробелы управляются через trivia поля (`name_suffix`, `lbrace_suffix`, `rparen_suffix` и т.д.).

### Правило 2: Парсер - источник истины
- **Парсер:** извлекает и сохраняет реальные пробелы из исходника
- **DSL:** генерирует пробелы по умолчанию (минимальные)
- **to_source:** только форматирует, не добавляет пробелов

### Правило 3: Именование trivia полей
- `element_suffix` - пробел ПОСЛЕ элемента
- `element_prefix` - пробел ДО элемента
- `element_suffix` и `element_prefix` - пробелы вокруг элемента

### Правило 4: DSL дефолты
DSL использует пустые строки для компактности, пробелы добавляются только при необходимости.

## Стандартные форматы

### Enum declarations
```cpp
enum class State{INIT, READY = 1, ERROR = 2};  // без пробела перед {
enum class Format : uint8_t{A8, RGB8};         // пробел перед :
```

### Function declarations
```cpp
void function() { }                    // пробел перед {
void function() const noexcept { }     // пробел перед const
static inline void function() { }      // правильный порядок модификаторов
```

### Template declarations
```cpp
template <typename T>                  // пробел в <>
template <>                           // без пробела в <>
```

### Friend declarations
```cpp
friend class Friend1;                 // пробел перед class
friend Friend3;                       // пробел перед именем
```

## Реализация

### ModifierSet
Порядок модификаторов определяется приоритетами:
```ruby
PRIORITY = {
  static: 1, constexpr: 2, explicit: 3, inline: 4, virtual: 5,
  maybe_unused: 9, nodiscard: 10
}.freeze
```

### Parameter Node
Параметры - полноценные AST узлы с контролем пробелов:
```ruby
class Parameter < Base
  attr_accessor :type_suffix, :equals_prefix, :equals_suffix
end
```

### Trivia в токенах
Все trivia управляется через токены:
```ruby
token.leading_trivia  # пробелы перед токеном
token.trailing_trivia # пробелы после токена
```

## Проверка соответствия

- ✅ Жёстких пробелов в to_source: 0
- ✅ Порядок модификаторов: автоматический через ModifierSet
- ✅ Parameter как узел: ✅
- ✅ Trivia в токенах: ✅
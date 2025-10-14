# Примеры использования C++ AST Parser V3

Эта папка содержит практические примеры использования C++ AST Parser V3 и Aurora DSL.

## Примеры

### 01_basic_dsl.rb - Базовый DSL
Демонстрирует основные возможности DSL Builder:
- Создание простых функций
- Выражения и операторы
- Control flow (if, for, while)
- Roundtrip тестирование

**Запуск**: `ruby examples/01_basic_dsl.rb`

### 02_bidirectional_roundtrip.rb - Bidirectional DSL
Показывает полный цикл C++ → AST → DSL → AST → C++:
- Парсинг C++ кода в AST
- Генерация Ruby DSL кода
- Восстановление AST из DSL
- Fluent API для trivia

**Запуск**: `ruby examples/02_bidirectional_roundtrip.rb`

### 03_trivia_preservation.rb - Сохранение trivia
Демонстрирует работу с trivia (whitespace, комментарии):
- Токенизация с trivia
- Восстановление исходного кода
- Обработка комментариев и preprocessor директив

**Запуск**: `ruby examples/03_trivia_preservation.rb`

### 04_aurora_dsl.rb - Aurora DSL расширения
Показывает современные C++ конструкции через Aurora DSL:
- Ownership типы (std::unique_ptr, const T&, std::span)
- ADT (Product/Sum типы)
- Pattern matching (std::visit)
- Result/Option типы (std::expected, std::optional)

**Запуск**: `ruby examples/04_aurora_dsl.rb`

## Требования

- Ruby 3.0+
- C++ AST Parser V3 (установлен в lib/)

## Запуск всех примеров

```bash
# Из корня проекта
ruby examples/01_basic_dsl.rb
ruby examples/02_bidirectional_roundtrip.rb
ruby examples/03_trivia_preservation.rb
ruby examples/04_aurora_dsl.rb
```

## Ожидаемый результат

Все примеры должны:
- ✅ Выполняться без ошибок
- ✅ Генерировать корректный C++ код
- ✅ Показывать roundtrip accuracy
- ✅ Демонстрировать возможности Aurora DSL

## Дополнительные ресурсы

- [Документация DSL Builder](../docs/DSL_BUILDER.md)
- [Aurora DSL документация](../docs/AURORA_DSL.md)
- [Статус проекта](../docs/PROJECT_STATUS.md)
- [Основной README](../README.md)

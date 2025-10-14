# TODO - Конкретные задачи

## Высокий приоритет

### Документация
- [ ] Обновить главный README.md с разделом Aurora DSL
- [ ] Добавить Aurora раздел в docs/DSL_BUILDER.md
- [ ] Создать migration guide (C++ → DSL)
- [ ] Документировать best practices Aurora DSL

### DSL Generator для Aurora
- [ ] Добавить поддержку `OwnedType` в DSL Generator
- [ ] Добавить поддержку `BorrowedType` в DSL Generator
- [ ] Добавить поддержку `MutBorrowedType` в DSL Generator
- [ ] Добавить поддержку `SpanType` в DSL Generator
- [ ] Добавить поддержку `ExpectedType` в DSL Generator
- [ ] Добавить поддержку `OptionalType` в DSL Generator
- [ ] Добавить поддержку `SumTypeDeclaration` в DSL Generator
- [ ] Добавить поддержку `MatchExpression` в DSL Generator

### Тестирование
- [ ] Добавить тесты для DSL Generator с ownership типами
- [ ] Добавить тесты для DSL Generator с Result/Option типами
- [ ] Добавить тесты для DSL Generator с Product/Sum типами
- [ ] Добавить тесты для DSL Generator с Pattern Matching
- [ ] Проверить roundtrip для всех Aurora конструкций

## Средний приоритет

### Parser расширения
- [ ] Добавить поддержку template в parser
- [ ] Добавить поддержку concepts (C++20) в parser
- [ ] Добавить поддержку modules (C++20) в parser
- [ ] Добавить поддержку coroutines (C++20) в parser
- [ ] Добавить поддержку structured bindings в parser

### DSL Builder расширения
- [ ] Добавить поддержку template в DSL Builder
- [ ] Добавить поддержку concepts в DSL Builder
- [ ] Добавить поддержку modules в DSL Builder
- [ ] Добавить поддержку coroutines в DSL Builder
- [ ] Добавить поддержку structured bindings в DSL Builder

### Performance
- [ ] Профилирование парсера на больших файлах
- [ ] Оптимизация memory allocation в parser
- [ ] Кэширование AST узлов
- [ ] Параллельный парсинг для больших проектов
- [ ] Benchmark suite для performance тестов

### Error Handling
- [ ] Улучшить error messages в parser
- [ ] Добавить error recovery в parser
- [ ] Добавить warning system
- [ ] Улучшить error reporting в DSL Generator

## Низкий приоритет

### LSP Server
- [ ] Спроектировать LSP сервер архитектуру
- [ ] Реализовать базовые LSP функции (initialize, textDocument/didOpen)
- [ ] Добавить autocomplete для DSL
- [ ] Добавить hover information
- [ ] Добавить error reporting через LSP
- [ ] Добавить go-to-definition
- [ ] Добавить find-references

### VS Code расширение
- [ ] Создать VS Code расширение проект
- [ ] Интеграция с LSP сервером
- [ ] Syntax highlighting для DSL
- [ ] Snippets и templates
- [ ] Debugging support
- [ ] Configuration options

### Migration Tools
- [ ] Создать C++ → DSL migration tool
- [ ] Создать DSL → C++ migration tool
- [ ] Добавить batch processing
- [ ] Добавить incremental migration
- [ ] Интеграция с build systems

### Экосистема
- [ ] Создать package manager для DSL
- [ ] Стандартная библиотека DSL
- [ ] Community templates
- [ ] Best practices guide
- [ ] Tutorial series

## Исследовательские задачи

### ESM модули
- [ ] Проанализировать необходимость ESM модулей
- [ ] Спроектировать API для ESM
- [ ] Создать proof-of-concept
- [ ] Оценить сложность реализации
- [ ] Принять решение о реализации

### Новые языковые конструкции
- [ ] Исследовать async/await для DSL
- [ ] Изучить macro system возможности
- [ ] Анализ compile-time execution
- [ ] Исследование metaprogramming возможности

### Интеграция
- [ ] Rust FFI integration исследование
- [ ] Python bindings
- [ ] JavaScript/TypeScript integration
- [ ] WebAssembly support

## Техническая задолженность

### Рефакторинг
- [ ] Рефакторинг parser architecture
- [ ] Улучшение error recovery
- [ ] Добавление incremental parsing
- [ ] Поддержка partial AST

### Тестирование
- [ ] Property-based testing для parser
- [ ] Fuzzing для parser
- [ ] Memory leak detection
- [ ] Performance regression tests

### Документация
- [ ] API documentation для всех классов
- [ ] Architecture documentation
- [ ] Contributing guide
- [ ] Code style guide

## Критерии завершения

### Краткосрочные (1-2 недели)
- [ ] Все задачи из "Высокий приоритет" выполнены
- [ ] Документация обновлена
- [ ] DSL Generator поддерживает Aurora типы
- [ ] Все тесты проходят

### Среднесрочные (1-2 месяца)
- [ ] Parser coverage 100% для C++20
- [ ] Performance улучшен на 50%
- [ ] LSP сервер работает
- [ ] VS Code расширение готово

### Долгосрочные (3+ месяца)
- [ ] Production-ready LSP сервер
- [ ] Успешная миграция реального проекта
- [ ] Активное community
- [ ] Стабильная экосистема

## Примечания

- Задачи отсортированы по приоритету
- Каждая задача должна быть конкретной и измеримой
- При выполнении задачи отмечать как [x]
- Регулярно обновлять TODO.md
- Связывать задачи с GitHub Issues

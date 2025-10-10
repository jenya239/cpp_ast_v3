# План доработки: Trivia в токенах

Дата: 2025-10-10  
Основа: TRIVIA_IN_TOKENS_ROADMAP.md, CST_ARCHITECTURE_SUMMARY.md, BUGFIX_REPORT_2025-10-10.md

## Цель
Перенести trivia из парсера в токены для соответствия lossless CST архитектуре.

## Текущее vs Целевое

**БЫЛО**: Trivia как отдельные токены → парсер собирает вручную  
**БУДЕТ**: Token имеет `leading_trivia` и `trailing_trivia` → парсер использует из токенов

## Этапы (4-6 часов)

### Этап 1: Token (30 мин)
**Файлы**: `lib/cpp_ast/lexer/token.rb`, `test/lexer/token_test.rb`

- Добавить `attr_accessor :leading_trivia, :trailing_trivia`
- Расширить `initialize` для trivia параметров
- Написать тесты

### Этап 2: Lexer (2-3 часа)  
**Файлы**: `lib/cpp_ast/lexer/lexer.rb`, `test/lexer/lexer_basic_test.rb`

**Новый алгоритм**:
1. Собрать leading trivia перед токеном → `collect_trivia_as_string`
2. Сканировать non-trivia токен
3. Присвоить leading trivia токену
4. Собрать trailing trivia → присвоить токену
5. EOF токен получает leading trivia (trailing всегда пусто)

**Методы**:
- `collect_trivia_as_string` - собирает trivia в строку
- `trivia_ahead?` - проверяет whitespace/comment/preprocessor
- `scan_trivia_token` - сканирует trivia (не добавляет в массив)
- `scan_non_trivia_token` - сканирует обычный токен

**Тесты**: leading/trailing trivia, multiple tokens, edge cases

### Этап 3: Parser (1-2 часа)
**Файлы**: `lib/cpp_ast/parsers/*.rb`

**Изменения**:
- `base_parser.rb`: удалить `collect_trivia_string`, добавить `current_leading_trivia`
- `program_parser.rb`: убрать manual trivia collection, использовать token trivia
- `statement_parser.rb`: изменить сигнатуры - убрать `leading_trivia` параметр

**Принцип**: Парсер берёт trivia из `current_token.leading_trivia`

### Этап 4: Тестирование (30 мин)
- `rake test` → все 481 теста проходят
- `scripts/verify_roundtrip.rb` → 100% success
- Проверка на gtk_gl_sample.cpp

## Порядок внедрения (incremental)

### Итерация 1: Token + тесты → commit
### Итерация 2: Lexer + тесты → проверка → commit  
### Итерация 3: Parser → все тесты → commit
### Итерация 4: Roundtrip → commit

## Риски

| Риск | Вероятность | Митигация |
|------|-------------|-----------|
| Сломать tokenize | Средняя | Тесты перед изменениями, инкрементальный подход |
| Сломать roundtrip | Низкая | Проверка после каждого этапа |
| Производительность | Низкая | Профилирование до/после |

## Критерии успеха
✅ 481 тест проходит (0 failures)  
✅ 100% roundtrip на fixtures  
✅ Token самодостаточен (содержит trivia)  
✅ Парсер упрощён (не собирает trivia вручную)

## Документы
- `TRIVIA_IN_TOKENS_ROADMAP.md` - детальный план
- `CST_ARCHITECTURE_SUMMARY.md` - обзор архитектуры
- `cpp_parser_arch.md` - эталонная архитектура CST


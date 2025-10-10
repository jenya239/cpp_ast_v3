# Рефакторинг Phase 2: Дальнейшее разделение модулей

## Текущее состояние после Phase 1

| Модуль | Строк | Проблема |
|--------|-------|----------|
| statement_parser.rb | 1314 | ❌ Слишком большой |
| expression_parser.rb | 540 | ⚠️  Большой |
| control_flow_parser.rb | 411 | ⚠️  Приемлемо |
| declaration_parser.rb | 28 | ❌ Пустой (методы не перенесены) |
| type_parser.rb | 116 | ✅ OK |
| base_parser.rb | 129 | ✅ OK |
| program_parser.rb | 82 | ✅ OK |

## Задачи Phase 2

### Задача 1: Физический перенос DeclarationParser (Критично!)

**Проблема**: DeclarationParser пустой, все методы всё ещё в statement_parser.rb

**Перенести ~900 строк:**
- parse_namespace_declaration (52 строки)
- parse_function_declaration + 9 helpers (~350 строк)
- parse_class_like_declaration (82 строки)
- parse_class_declaration, parse_struct_declaration (10 строк)
- parse_variable_declaration + 4 helpers (~150 строк)
- parse_using_declaration (120 строк)
- parse_template_declaration (60 строк)
- parse_enum_declaration (73 строки)
- looks_like_function_declaration? + 5 helpers (~200 строк)
- looks_like_declaration? (52 строки)

**Результат**: 
- declaration_parser.rb: 28 → ~930 строк
- statement_parser.rb: 1314 → ~400 строк

### Задача 2: Разделение expression_parser.rb

**Текущий размер**: 540 строк

**План разделения на 3 модуля:**

1. **primary_expression_parser.rb** (~180 строк):
   - parse_primary_expression
   - parse_lambda_expression
   - parse_brace_initializer

2. **postfix_expression_parser.rb** (~200 строк):
   - parse_function_call_expression
   - parse_member_access_expression
   - parse_array_subscript_expression
   - parse_postfix_expression

3. **binary_expression_parser.rb** (~160 строк):
   - parse_binary_expression (Pratt parser)
   - parse_ternary_expression
   - precedence/binding_power logic

**expression_parser.rb останется** как координатор (~50 строк):
- parse_expression (entry point)
- включение 3-х модулей

### Задача 3: Улучшение control_flow_parser.rb

**Текущий размер**: 411 строк

**Оптимизация** - группировка похожих методов:
- Создать helper `parse_statement_with_condition` для if/while
- Создать helper `parse_loop_body` для while/for/do-while
- Уменьшить до ~320 строк

## Целевые метрики Phase 2

| Модуль | Было | Будет | Статус |
|--------|------|-------|--------|
| statement_parser.rb | 1314 | ~380 | ✅ Приемлемо |
| declaration_parser.rb | 28 | ~930 | ✅ Логичный размер |
| expression_parser.rb | 540 | ~50 | ✅ Координатор |
| primary_expression_parser.rb | - | ~180 | ✅ Новый |
| postfix_expression_parser.rb | - | ~200 | ✅ Новый |
| binary_expression_parser.rb | - | ~160 | ✅ Новый |
| control_flow_parser.rb | 411 | ~320 | ✅ Оптимизирован |

## Критерий успеха

✅ Нет модулей > 1000 строк
✅ Нет модулей > 50 методов  
✅ Логическое разделение по ответственности
✅ Все 490 тестов проходят
✅ Roundtrip fidelity сохранён

## Порядок выполнения

1. **Задача 1** (критично): Перенос в DeclarationParser
2. **Задача 2**: Разделение expression_parser
3. **Задача 3**: Оптимизация control_flow_parser

После каждой задачи - полный прогон тестов!


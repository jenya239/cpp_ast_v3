# DSL Gap Analysis - Что уже есть vs что нужно

## DSL Builder (27 методов) ✅
**Уже реализовано** в `lib/cpp_ast/builder/dsl.rb`:

```ruby
# Literals (4)
int, float, string, char

# Identifiers (1)
id

# Expressions (8)
binary, unary, unary_post, paren, call, member, subscript, ternary

# Statements (7)
expr_stmt, return_stmt, block, if_stmt, while_stmt, for_stmt
break_stmt, continue_stmt

# Declarations (5)
var_decl, function_decl, namespace_decl, class_decl, struct_decl

# Program (1)
program
```

## DSL Generator (16 методов) ⚠️
**Реализовано** в `lib/cpp_ast/builder/dsl_generator.rb`:

```ruby
# Literals (4) ✅
generate_number_literal, generate_string_literal, generate_char_literal, generate_identifier

# Expressions (5) ✅
generate_binary_expression, generate_unary_expression, generate_parenthesized_expression
generate_function_call_expression, generate_member_access_expression

# Statements (4) ✅
generate_expression_statement, generate_return_statement, generate_block_statement, generate_if_statement

# Declarations (2) ✅
generate_variable_declaration, generate_function_declaration

# Program (1) ✅
generate_program
```

---

## GAP: DSL builder есть, generator НЕТ (11 методов) ❌

### Легко добавить (5 минут каждый):

1. **`subscript`** → `generate_array_subscript_expression`
   ```ruby
   def generate_array_subscript_expression(node)
     arr = generate(node.array)
     idx = generate(node.index)
     result = "subscript(#{arr}, #{idx})"
     # + fluent для lbracket_suffix, rbracket_prefix
   end
   ```
   **Сложность**: 🟢 Тривиально (паттерн известен)

2. **`ternary`** → `generate_ternary_expression`
   ```ruby
   def generate_ternary_expression(node)
     cond = generate(node.condition)
     true_expr = generate(node.true_expression)
     false_expr = generate(node.false_expression)
     result = "ternary(#{cond}, #{true_expr}, #{false_expr})"
     # + fluent для question_*/colon_*
   end
   ```
   **Сложность**: 🟢 Тривиально

3. **`break_stmt`** → `generate_break_statement`
   ```ruby
   def generate_break_statement(node)
     result = "break_stmt"
     result += "\n.with_leading(...)" if node.leading_trivia != ""
   end
   ```
   **Сложность**: 🟢 Тривиально (самый простой)

4. **`continue_stmt`** → `generate_continue_statement`
   ```ruby
   # Аналогично break_stmt
   ```
   **Сложность**: 🟢 Тривиально

5. **`while_stmt`** → `generate_while_statement`
   ```ruby
   def generate_while_statement(node)
     cond = generate(node.condition)
     body = generate(node.body)
     result = "while_stmt(#{cond},\n#{indent}#{body})"
     # + fluent для while_suffix и condition_*
   end
   ```
   **Сложность**: 🟢 Легко (похоже на if_stmt)

### Средней сложности (15-20 минут):

6. **`for_stmt`** → `generate_for_statement`
   ```ruby
   def generate_for_statement(node)
     # Проблема: init может быть Expression ИЛИ текст (range-based for)
     # Нужно различать classic vs range-based
     if node.init_trailing.start_with?(":")
       # Range-based: for (auto x : vec)
       # init сохранён как Identifier с текстом
     else
       # Classic: for (i = 0; i < 10; i++)
     end
   end
   ```
   **Сложность**: 🟡 **Нетривиально** - две разные формы for
   **Проблема**: `init` - это Expression или текст?

7. **`namespace_decl`** → `generate_namespace_declaration`
   ```ruby
   def generate_namespace_declaration(node)
     body = generate(node.body)
     result = "namespace_decl(#{node.name.inspect},\n#{indent}#{body})"
     # + fluent для namespace_suffix, name_suffix
   end
   ```
   **Сложность**: 🟡 Средне (вложенность body)

8. **`class_decl`** → `generate_class_declaration`
   ```ruby
   def generate_class_declaration(node)
     # Проблема: members - это массив разных типов
     # Проблема: base_classes_text - строка, а не AST
     members = node.members.map { |m| generate(m) }
     result = "class_decl(#{node.name.inspect}"
     # Как передать member_trailings?
     # Как передать base_classes_text?
   end
   ```
   **Сложность**: 🟡 **Нетривиально** - наследование, члены
   **Проблема**: `base_classes_text` - строка, не AST

9. **`struct_decl`** → `generate_struct_declaration`
   ```ruby
   # Аналогично class_decl
   ```
   **Сложность**: 🟡 **Нетривиально** - те же проблемы

---

## GAP: Вообще нигде нет (14 типов) ❌

### В parser есть, но нет ни в DSL builder, ни в generator:

10. **DoWhileStatement** - `do { } while (cond);`
    **Сложность**: 🟢 Легко

11. **SwitchStatement** + **CaseClause** + **DefaultClause**
    ```ruby
    # Нужны 3 новых метода
    switch_stmt(expr, *cases)
    case_clause(value, *stmts)
    default_clause(*stmts)
    ```
    **Сложность**: 🟡 Средне (вложенная структура)

12. **EnumDeclaration** - `enum Color { Red, Green };`
    ```ruby
    enum_decl(name, enumerators_text)
    # Проблема: enumerators - строка, не AST
    ```
    **Сложность**: 🟡 **Нетривиально** - enumerators как текст

13. **TemplateDeclaration** - `template<typename T> class Foo {};`
    ```ruby
    template_decl(params_text, declaration)
    # Проблема: template_params - строка, не AST
    ```
    **Сложность**: 🔴 **Сложно** - template параметры

14. **LambdaExpression** - `[capture](params) { body }`
    ```ruby
    lambda_expr(capture_text, params_text, body)
    # Проблема: capture, parameters - текст
    ```
    **Сложность**: 🔴 **Сложно** - много текстовых частей

15. **BraceInitializerExpression** - `Type{args}`
    ```ruby
    brace_init(type, *args)
    ```
    **Сложность**: 🟢 Легко

16. **UsingDeclaration** - `using namespace std;`
    ```ruby
    using_decl(kind, name, alias_target: nil)
    ```
    **Сложность**: 🟡 Средне (3 варианта)

17. **AccessSpecifier** - `public:`, `private:`
    ```ruby
    access_spec(keyword)  # "public", "private", "protected"
    ```
    **Сложность**: 🟢 Тривиально

---

## Нетривиальные моменты

### 1. Текст vs AST ⚠️
Некоторые поля хранятся как **строки**, а не AST ноды:

```ruby
# В парсере:
ClassDeclaration.base_classes_text = ": public Base"  # Строка!
FunctionDeclaration.parameters = ["int a", "int b"]   # Массив строк!
EnumDeclaration.enumerators = "Red, Green, Blue"      # Строка!
TemplateDeclaration.template_params = "typename T"    # Строка!
```

**Проблема генерации DSL**:
```ruby
# Как генерировать?
class_decl("MyClass", members)
  .with_base_classes(": public Base")  # ??? Не красиво

# Или нужно парсить base_classes_text обратно в AST?
```

**Решения**:
- a) Генерировать "как есть" (строки) - просто, но не идеально
- b) Парсить строки → AST при генерации - сложно
- c) Расширить парсер хранить AST вместо строк - большая работа

### 2. Range-based for ⚠️
```cpp
// Classic for
for (int i = 0; i < 10; i++) { }

// Range-based for  
for (auto x : vec) { }
```

**Проблема**: В AST одна нода `ForStatement`, но два разных формата:
- Classic: `init` = Expression
- Range: `init` = Identifier с текстом "auto x"

**Решение**: Проверять `init_trailing.start_with?(":")`

### 3. Switch/Case вложенность ⚠️
```ruby
switch_stmt(expr,
  case_clause(1, stmt1, stmt2),
  case_clause(2, stmt3),
  default_clause(stmt4)
)
```

Нужны **3 новых builder метода** + fluent API для каждого

### 4. Template параметры 🔴
```cpp
template<typename T, int N = 10>
class Array { };
```

`template_params` = строка `"typename T, int N = 10"`

Как генерировать DSL? Парсить обратно?

---

## Оценка сложности доделывания

### Легко (1-2 часа) 🟢
Добавить в generator для уже существующих в DSL builder:
- `subscript` → `generate_array_subscript_expression` (5 мин)
- `ternary` → `generate_ternary_expression` (5 мин)
- `break_stmt` → `generate_break_statement` (3 мин)
- `continue_stmt` → `generate_continue_statement` (3 мин)
- `while_stmt` → `generate_while_statement` (10 мин)

**Итого**: 26 минут чистого кода + тесты

### Средне (2-4 часа) 🟡
Нетривиальные случаи:
- `for_stmt` → учесть range-based (20 мин)
- `namespace_decl` (15 мин)
- `class_decl` / `struct_decl` - решить проблему base_classes (30 мин)

**Итого**: 65 минут + тесты + решение архитектурных вопросов

### Сложно (4-8 часов) 🔴
Нужно создавать с нуля DSL builder + generator:
- Switch/Case/Default (3 метода) (1 час)
- EnumDeclaration (30 мин)
- DoWhileStatement (15 мин)
- BraceInitializerExpression (15 мин)
- UsingDeclaration (20 мин)
- AccessSpecifier (10 мин)

**Итого**: ~2.5 часа

### Очень сложно (8+ часов) 🔴🔴
Требуют решения архитектурных проблем:
- TemplateDeclaration - парсинг template параметров
- LambdaExpression - парсинг capture списков

**Итого**: Зависит от подхода к текстовым полям

---

## Рекомендация

### Фаза 1 (быстро, 1 час): 🟢
Докрыть то, что уже есть в DSL builder:
```
✅ subscript, ternary, break, continue, while (5 методов)
```
→ **Покрытие вырастет до 50%**

### Фаза 2 (средне, 2 часа): 🟡
Решить нетривиальные:
```
✅ for_stmt, namespace, class/struct (4 метода)
```
→ **Покрытие: 65%**

### Фаза 3 (долго, 4 часа): 🔴
Добавить новые конструкции:
```
✅ switch/case, enum, do-while, using, etc (9 методов)
```
→ **Покрытие: 90%**

### Фаза 4 (сложно): 🔴🔴
Templates, lambdas
→ **Покрытие: 100%**

---

## Вывод

**Легко доделать**: 🟢 5 методов (1 час)  
**Средне**: 🟡 4 метода (2 часа)  
**Сложно**: 🔴 9 методов (4 часа)  
**Очень сложно**: 🔴🔴 2 метода (архитектурные решения)

**Нетривиальные моменты**:
1. ⚠️ Текст vs AST (base_classes, template params, enumerators)
2. ⚠️ Range-based for
3. ⚠️ Вложенные структуры (switch/case)

**Общая оценка**: Базовые - легко, но есть **архитектурные вопросы** для сложных конструкций.


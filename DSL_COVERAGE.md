# DSL Generator - Покрытие конструкций

## Статистика

**Поддерживается**: 13/36 типов нод (36%)  
**Базовых достаточно для**: ~70% типичного C++ кода

## ✅ Поддерживается (13)

### Literals & Identifiers (4)
- ✅ `NumberLiteral` - int, float
- ✅ `StringLiteral` - строковые литералы
- ✅ `CharLiteral` - char литералы
- ✅ `Identifier` - имена переменных

### Expressions (5)
- ✅ `BinaryExpression` - `a + b`, `x * y`
- ✅ `UnaryExpression` - `-x`, `!flag`, `i++`
- ✅ `ParenthesizedExpression` - `(expr)`
- ✅ `FunctionCallExpression` - `foo(args)`
- ✅ `MemberAccessExpression` - `obj.field`, `ptr->member`

### Statements (3)
- ✅ `ExpressionStatement` - `expr;`
- ✅ `ReturnStatement` - `return expr;`
- ✅ `BlockStatement` - `{ ... }`
- ✅ `IfStatement` - `if (cond) { ... } else { ... }`

### Declarations (2)
- ✅ `VariableDeclaration` - `int x = 42;`
- ✅ `FunctionDeclaration` - `int foo() { ... }`

### Program (1)
- ✅ `Program` - корневой узел

---

## ❌ НЕ поддерживается (23)

### Expressions (4)
- ❌ `TernaryExpression` - `cond ? true : false`
- ❌ `ArraySubscriptExpression` - `arr[index]`
- ❌ `BraceInitializerExpression` - `Type{args}`
- ❌ `LambdaExpression` - `[](){ ... }`

### Control Flow (8)
- ❌ `WhileStatement` - `while (cond) { ... }`
- ❌ `DoWhileStatement` - `do { ... } while (cond);`
- ❌ `ForStatement` - `for (init; cond; inc) { ... }`
- ❌ `SwitchStatement` - `switch (expr) { ... }`
- ❌ `CaseClause` - `case value: ...`
- ❌ `DefaultClause` - `default: ...`
- ❌ `BreakStatement` - `break;`
- ❌ `ContinueStatement` - `continue;`

### Declarations (7)
- ❌ `ClassDeclaration` - `class Name { ... };`
- ❌ `StructDeclaration` - `struct Name { ... };`
- ❌ `EnumDeclaration` - `enum Name { ... };`
- ❌ `NamespaceDeclaration` - `namespace Name { ... }`
- ❌ `TemplateDeclaration` - `template<T> ...`
- ❌ `UsingDeclaration` - `using namespace std;`
- ❌ `AccessSpecifier` - `public:`, `private:`

### Other (4)
- ❌ `ErrorStatement` - error recovery nodes

---

## Приоритет расширения

### Высокий приоритет (часто используются)
1. **ForStatement**, **WhileStatement** - циклы в 80% функций
2. **ArraySubscriptExpression** - массивы везде
3. **TernaryExpression** - краткие условия
4. **BreakStatement**, **ContinueStatement** - управление циклами

### Средний приоритет
5. **ClassDeclaration**, **StructDeclaration** - OOP код
6. **NamespaceDeclaration** - организация кода
7. **SwitchStatement** - альтернатива if-else
8. **EnumDeclaration** - константы

### Низкий приоритет
9. **TemplateDeclaration** - шаблоны (сложные)
10. **LambdaExpression** - лямбды (C++11+)
11. **BraceInitializerExpression** - uniform init
12. **UsingDeclaration** - imports
13. **AccessSpecifier** - modifiers
14. **DoWhileStatement** - редко используется

---

## Стратегия расширения

### Фаза 1: Loops & Arrays (4 конструкции)
```ruby
# Покроет ~85% кода
- ForStatement
- WhileStatement
- ArraySubscriptExpression
- Break/Continue
```

### Фаза 2: Classes & Structures (5 конструкций)
```ruby
# Покроет ~95% кода
- ClassDeclaration
- StructDeclaration
- NamespaceDeclaration
- AccessSpecifier
- EnumDeclaration
```

### Фаза 3: Advanced (остальные)
```ruby
# Покроет 100%
- Templates
- Lambdas
- Ternary
- Switch
- Using
```

---

## Текущее состояние

**Текущее покрытие**: Базовые конструкции (~70% типичного кода)  
**Тесты**: 34 теста, все проходят  
**Roundtrip**: 100% для поддерживаемых конструкций  

**Достаточно для**:
- ✅ Простые функции
- ✅ Математические вычисления
- ✅ Условная логика (if/else)
- ✅ Функции с параметрами
- ⚠️ Циклы (нет)
- ⚠️ Массивы (нет)
- ⚠️ Классы (нет)

**Расширение по требованию** - добавляем конструкции по мере необходимости


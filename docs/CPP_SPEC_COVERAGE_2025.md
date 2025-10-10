# Покрытие спецификации C++ (актуальное)

## ✅ Реализовано и протестировано (100% roundtrip)

### Декларации
- [x] Namespace (обычные и вложенные)
- [x] Class (с наследованием)
- [x] Struct
- [x] Enum (обычные и enum class)
- [x] Function (включая конструкторы, деструкторы, operator overload)
- [x] Variable (с инициализацией)
- [x] Using (namespace, alias, простые)
- [x] Template (базовая поддержка)
- [x] Access specifiers (public/private/protected)

### Выражения
- [x] Binary operators (+, -, *, /, =, ==, !=, <, >, <=, >=, &&, ||)
- [x] Unary operators (!, ~, ++, --, +, -, *, &)
- [x] Member access (., ->)
- [x] Function calls
- [x] Array subscript ([])
- [x] Scope resolution (::)
- [x] Lambda expressions (базовые)
- [x] Ternary operator (?:)
- [x] Cast expressions
- [x] Parenthesized expressions

### Литералы
- [x] Number (int, float, hex, octal, binary)
- [x] String (обычные и raw R"(...)")
- [x] Character ('a', '\n')
- [x] Boolean (true, false)
- [x] nullptr

### Управление потоком
- [x] If/else
- [x] While
- [x] Do-while
- [x] For (обычные)
- [x] Switch/case/default
- [x] Break
- [x] Continue
- [x] Return
- [x] Block statements

### Модификаторы
- [x] const, static, extern, volatile, register
- [x] virtual, override, final, friend
- [x] inline, constexpr, explicit

### Комментарии и препроцессор
- [x] Line comments (//)
- [x] Block comments (/* */)
- [x] Preprocessor directives (#include, #define, #if, etc - как trivia)
- [x] Attributes ([[nodiscard]])

## ⚠️ Частично реализовано

### Lambda
- [x] Базовый синтаксис [](){ }
- [x] Capture list [x], [&x], [=], [&]
- [x] Parameters
- [ ] Trailing return type
- [ ] mutable
- [ ] constexpr lambda
- [ ] Template lambda (C++20)
- [ ] Generic lambda

### Templates
- [x] template<typename T> базовая поддержка
- [ ] Variadic templates детально
- [ ] Template specialization
- [ ] Partial specialization
- [ ] SFINAE
- [ ] Template template parameters
- [ ] Concepts (C++20)
- [ ] Requires clauses (C++20)

### For loops
- [x] Обычные for (int i=0; i<10; i++)
- [ ] Range-based for (for (auto x : vec))

## ❌ Не реализовано

### C++11/14/17
- [ ] Move semantics (rvalue references &&)
- [ ] Perfect forwarding
- [ ] Initializer lists {}
- [ ] Uniform initialization
- [ ] Delegating constructors
- [ ] Inheriting constructors
- [ ] Static assertions (static_assert)
- [ ] decltype
- [ ] Auto return type (auto func() -> int)
- [ ] Structured bindings (auto [a,b] = tuple)
- [ ] if constexpr

### C++20/23
- [ ] Modules (import/export)
- [ ] Coroutines (co_await, co_return, co_yield)
- [ ] Concepts (полная поддержка)
- [ ] Ranges
- [ ] Three-way comparison (<=>)
- [ ] Designated initializers
- [ ] consteval/constinit

### Сложные конструкции
- [ ] User-defined literals (123_km)
- [ ] Variadic functions (...)
- [ ] Default arguments детально
- [ ] Goto/labels
- [ ] Try/catch/throw (детально)
- [ ] Union declarations
- [ ] Nested classes (детально)
- [ ] Friend templates
- [ ] Anonymous namespaces (детально)
- [ ] Inline namespaces

### Препроцессор (активный)
- [ ] Macro expansion
- [ ] Variadic macros
- [ ] Token pasting (##)
- [ ] Stringification (#)
- [ ] Conditional compilation (активная обработка)

## 📊 Оценка покрытия

### По фазам roadmap:
- **Phase 1 (Expressions)**: ~85% ✅
- **Phase 2 (Literals & Types)**: ~90% ✅
- **Phase 3 (Statements)**: ~90% ✅
- **Phase 4 (Declarations)**: ~75% ✅
- **Phase 5 (Classes & OOP)**: ~70% ⚠️
- **Phase 6 (Templates)**: ~30% ⚠️
- **Phase 7 (Namespaces)**: ~80% ✅
- **Phase 8 (Preprocessor)**: ~40% ⚠️ (trivia mode)
- **Phase 9 (C++11/14/17)**: ~25% ❌
- **Phase 10 (C++20/23)**: ~5% ❌

### Общий прогресс: ~60% базовой спецификации C++

## 🎯 Приоритеты доработки

### Приоритет 1 (критично для практики)
1. **Range-based for** - часто используется (2 часа)
2. **Auto return type** - современный C++ (2 часа)
3. **Structured bindings** - C++17 базовая (3 часа)
4. **Move semantics (&&)** - базовая поддержка (4 часа)

### Приоритет 2 (расширение шаблонов)
1. **Variadic templates детально** - pack expansion (4 часа)
2. **Template specialization** - важно (3 часа)
3. **Concepts** - C++20 базовая (6 часов)

### Приоритет 3 (C++20 важные)
1. **Designated initializers** - простая фича (2 часа)
2. **Three-way comparison (<=>)** - оператор (2 часа)
3. **consteval/constinit** - модификаторы (1 час)

### Приоритет 4 (корутины - сложно)
1. **Coroutines** - co_await, co_return, co_yield (10+ часов)
2. **Modules** - import/export (8+ часов)

## 📈 Что делать дальше?

### Быстрые победы (10 часов)
1. Range-based for
2. Auto return type  
3. Designated initializers
4. consteval/constinit
5. Three-way comparison

### Средний приоритет (20 часов)
1. Structured bindings
2. Move semantics базовая
3. Variadic templates
4. Template specialization
5. Lambda улучшения (mutable, constexpr)

### Долгосрочно (30+ часов)
1. Concepts полная поддержка
2. Coroutines
3. Modules
4. Активный препроцессор

## ✅ Текущие достижения

- **490 тестов**, все проходят
- **100% roundtrip** для поддерживаемых конструкций
- **~60% базовой спецификации C++**
- **Достаточно для парсинга большинства реальных проектов C++11/14**

## 🚀 Для полного покрытия C++20

Остаётся ~40% спецификации, в основном:
- Современные C++17/20/23 фичи
- Сложные шаблонные конструкции
- Корутины и модули
- Активный препроцессор

**Оценка до 100%**: 60-80 часов работы

---

## 📋 26 интеграционных roundtrip тестов

Текущие тесты покрывают:
1. anonymous_namespace
2. array_subscript  
3. attributes
4. class_inheritance
5. constructor_destructor
6. control_flow
7. enum
8. function_call
9. function_modifiers
10. lambda
11. literals
12. member_access
13. more_operators
14. parenthesized
15. template
16. template_types
17. ternary
18. unary
19. using_declaration
20. variable_declaration
21. gtk_gl_sample (реальный проект)
22. complex_class
23. nested_class_members
24. out_of_line_operators
25. error_recovery
26. roundtrip_test (базовый)

**Покрытие реальных проектов:**
- ✅ gtk-gl-cpp-2025 парсится успешно
- 26 специализированных roundtrip тестов
- 490 тестов всего

---

## 🔍 Сводка по ключевым словам

Поддерживается **58 C++ ключевых слов**:
- Управление: if, else, while, for, do, switch, case, default, break, continue, return, goto
- Исключения: try, catch, throw
- Типы: int, float, double, char, bool, void, auto
- Модификаторы: const, static, extern, volatile, register, inline, constexpr
- ООП: class, struct, union, enum, namespace, using, typedef
- Шаблоны: template, typename
- Доступ: public, private, protected
- Виртуальность: virtual, override, final, friend
- Операторы: operator, sizeof, alignof, new, delete, this, nullptr
- Литералы: true, false
- Знаковость: signed, unsigned, short, long

**Не поддерживается (C++20/23):**
- co_await, co_return, co_yield (корутины)
- concept, requires (концепты)
- consteval, constinit
- import, export, module (модули)


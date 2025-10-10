# Известные проблемы парсера (Октябрь 2025)

## Критические проблемы

### 1. Structured Bindings (C++17) не поддерживаются ⛔

**Пример:**
```cpp
for (const auto& [key, value] : map) {
    use(key);
}
```

**Проблема:**
- Парсер не распознает `[key, value]` как valid identifier
- Все пробелы теряются
- Выход: `constauto&[key,value]:map){use(key);}`

**Решение:**
1. Добавить поддержку `[` `]` в `parse_variable_type` / `parse_for_statement`
2. Создать `StructuredBinding` node или обрабатывать как специальный case
3. Сохранять структуру `[id1, id2, ...]` как часть declarator

**Оценка:** 2-3 часа

**Файлы для тестирования:**
- src/demos/demo_manager.cpp (строка ~27)
- src/core/app_state.cpp
- src/widgets/demo_selector.cpp

---

## Средние проблемы

### 2. Сложные классы с множественным наследованием ⚠️

**Пример:**
```cpp
class AnimatedTriangleDemo : public DemoScene {
public:
    ~AnimatedTriangleDemo() override = default;
    void on_realize(GtkGLArea* area) override;
    // ...
};
```

**Проблема:**
- В некоторых сложных headers с preprocessor directives и классами 
  парсер генерирует ErrorStatements

**Файлы:**
- include/demos/animated_triangle_demo.hpp
- include/demos/rotating_cube_demo.hpp

**Решение:** Требуется детальный анализ

---

## Статистика

### Текущее покрытие: 12/40 (30%)

✅ **Работает:**
- Простые headers без сложных конструкций
- .cpp файлы без structured bindings

❌ **Не работает:**
- .cpp файлы со structured bindings (28 файлов)
- Некоторые сложные headers (8 файлов)

### После fix structured bindings: ~38/40 (95%)

Оставшиеся 2-3 файла требуют анализа специфических edge cases.


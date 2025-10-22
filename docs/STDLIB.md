# Aurora Standard Library

Aurora Standard Library предоставляет набор модулей с общими функциями и типами для разработки на Aurora.

## Модули

### Math
Математические функции и константы.

```aurora
import Math

fn example() -> i32 =
  let x = Math.abs(-5) in
  let y = Math.min(3, 7) in
  let z = Math.max(3, 7) in
  x + y + z
```

**Основные функции:**
- `abs(x: i32) -> i32` - абсолютное значение
- `abs_f(x: f32) -> f32` - абсолютное значение для float
- `min(a: i32, b: i32) -> i32` - минимум
- `max(a: i32, b: i32) -> i32` - максимум
- `pow(base: i32, exp: i32) -> i32` - возведение в степень
- `sqrt(x: f32) -> f32` - квадратный корень
- `sin(x: f32) -> f32` - синус
- `cos(x: f32) -> f32` - косинус

**Константы:**
- `PI: f32` - число π
- `E: f32` - число e

### Collections
Утилиты для работы с коллекциями.

```aurora
import Collections

fn example() -> i32[] =
  let arr = [1, 2, 3, 4, 5] in
  let doubled = Collections.map(arr, x => x * 2) in
  let filtered = Collections.filter(doubled, x => x > 5) in
  filtered
```

**Основные функции:**
- `map<T, U>(arr: T[], f: T -> U) -> U[]` - преобразование элементов
- `filter<T>(arr: T[], pred: T -> bool) -> T[]` - фильтрация элементов
- `fold<T, U>(arr: T[], init: U, f: (U, T) -> U) -> U` - свертка
- `find<T>(arr: T[], pred: T -> bool) -> Option<T>` - поиск элемента
- `contains<T>(arr: T[], item: T) -> bool` - проверка наличия элемента

### String
Операции со строками.

```aurora
import String

fn example() -> str =
  let s = "  hello world  " in
  let trimmed = String.trim(s) in
  let upper = String.upper(trimmed) in
  upper
```

**Основные функции:**
- `length(s: str) -> i32` - длина строки
- `trim(s: str) -> str` - удаление пробелов
- `upper(s: str) -> str` - верхний регистр
- `lower(s: str) -> str` - нижний регистр
- `split(s: str, delimiter: str) -> str[]` - разделение строки
- `join(strings: str[], delimiter: str) -> str` - объединение строк
- `contains(s: str, substring: str) -> bool` - поиск подстроки
- `starts_with(s: str, prefix: str) -> bool` - проверка префикса
- `ends_with(s: str, suffix: str) -> bool` - проверка суффикса

### IO
Ввод/вывод и системные функции.

```aurora
import IO

fn example() -> void =
  IO.println("Hello, world!");
  IO.debug_print("Debug message")
```

**Основные функции:**
- `print(s: str) -> i32` - вывод без перевода строки
- `println(s: str) -> i32` - вывод с переводом строки
- `read_line() -> str` - чтение строки
- `input(prompt: str) -> str` - ввод с приглашением
- `args() -> str[]` - аргументы командной строки
- `debug_print(s: str) -> void` - отладочный вывод
- `panic(message: str) -> void` - аварийное завершение

### Option
Тип Option для безопасной работы с отсутствующими значениями.

```aurora
import Option

fn example() -> i32 =
  let some_value = Option.Some(42) in
  let none_value = Option.None in
  let result1 = Option.unwrap_or(some_value, 0) in
  let result2 = Option.unwrap_or(none_value, 0) in
  result1 + result2
```

**Основные функции:**
- `is_some<T>(opt: Option<T>) -> bool` - проверка наличия значения
- `is_none<T>(opt: Option<T>) -> bool` - проверка отсутствия значения
- `unwrap<T>(opt: Option<T>) -> T` - извлечение значения (небезопасно)
- `unwrap_or<T>(opt: Option<T>, default: T) -> T` - извлечение с значением по умолчанию
- `map<T, U>(opt: Option<T>, f: T -> U) -> Option<U>` - преобразование значения
- `filter<T>(opt: Option<T>, pred: T -> bool) -> Option<T>` - фильтрация значения

**Тип Result:**
- `Result<T, E> = Ok(T) | Err(E)` - тип для обработки ошибок
- `ok<T, E>(value: T) -> Result<T, E>` - создание успешного результата
- `err<T, E>(error: E) -> Result<T, E>` - создание ошибочного результата

### Prelude
Главный модуль с общими утилитами.

```aurora
import Prelude

fn example() -> i32 =
  let x = Prelude.identity(42) in
  let y = Prelude.const(10)(20) in
  x + y
```

**Основные функции:**
- `identity<T>(x: T) -> T` - тождественная функция
- `const<T, U>(x: T) -> U -> T` - константная функция
- `compose<T, U, V>(f: U -> V, g: T -> U) -> T -> V` - композиция функций
- `pipe<T, U, V>(x: T, f: T -> U, g: U -> V) -> V` - цепочка функций
- `dbg<T>(x: T) -> T` - отладочный вывод значения
- `assert(condition: bool, message: str) -> void` - проверка условия
- `range(start: i32, end: i32) -> i32[]` - создание диапазона чисел

## Использование

### Импорт модулей

```aurora
import Math
import Collections
import String
import IO
import Option
```

### Пример программы

```aurora
import Math
import Collections
import String
import IO

fn main() -> i32 =
  let numbers = [1, 2, 3, 4, 5] in
  let doubled = Collections.map(numbers, x => x * 2) in
  let filtered = Collections.filter(doubled, x => x > 5) in
  let sum = Collections.fold(filtered, 0, (acc, x) => acc + x) in
  
  IO.println("Sum: " + String.to_string(sum));
  sum
```

## Ограничения

1. **Файловая система**: Функции работы с файлами пока не реализованы
2. **Переменные окружения**: Функции работы с переменными окружения пока не реализованы
3. **Процессы**: Функции управления процессами пока не реализованы
4. **Мутабельность**: Некоторые функции требуют мутабельных массивов

## Планы развития

- [ ] Реализация файловой системы
- [ ] Поддержка переменных окружения
- [ ] Управление процессами
- [ ] Асинхронное программирование
- [ ] Сетевые функции
- [ ] Криптографические функции
- [ ] Работа с датами и временем

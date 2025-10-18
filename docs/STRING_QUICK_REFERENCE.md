# Строки в Aurora - Краткая справка

## Два типа строк

### `String` - для удобства (как JS/Ruby)

```aurora
let s = "Hello, мир! 🌍";  // String по умолчанию

s.length();        // 14 (символы!)
s.char_at(7);      // 'м'
s.upper();         // "HELLO, МИР! 🌍"
s.split(", ");     // ["Hello", "мир! 🌍"]
```

### `Bytes` - для контроля (FFI, бинарные данные)

```aurora
let b: Bytes = s.to_bytes();

b.size();          // 23 (байты!)
b[0];              // 72 (ASCII 'H')
b.as_ptr();        // *const u8 для C функций
```

## Когда использовать что?

### Используй `String` для:

✅ Обработки пользовательского ввода
✅ Работы с текстом (парсинг, форматирование)
✅ Операций с символами (substring, split, trim)
✅ Unicode текста
✅ Когда важно удобство

```aurora
// Обработка текста
fn normalize_username(name: String) -> String =
  name.trim().lower()

// Форматирование
fn greet(name: String) -> String =
  "Hello, {name}!"

// Парсинг
fn parse_csv(line: String) -> [String] =
  line.split(",")
```

### Используй `Bytes` для:

✅ FFI с C библиотеками
✅ Бинарных протоколов
✅ Работы с конкретной кодировкой
✅ Когда нужен прямой доступ к памяти
✅ Чтения бинарных файлов

```aurora
// FFI
extern fn write(fd: i32, buf: *const u8, count: i32) -> i32;

fn write_to_file(text: String) =
  let bytes = text.to_bytes();
  write(1, bytes.as_ptr(), bytes.size());

// Бинарный протокол
fn parse_header(data: Bytes) -> Header =
  Header {
    magic: data.read_u32_be(0),
    version: data[4],
    length: data.read_u16_be(5)
  }
```

## Сравнение операций

| Операция | String | Bytes |
|----------|--------|-------|
| Длина | `.length()` (символы) | `.size()` (байты) |
| Доступ | `.char_at(i)` (char) | `[i]` (u8) |
| Подстрока | `.substring(0, 5)` | `.slice(0, 5)` |
| Итерация | `for c in s.chars()` | `for b in bytes` |
| Для FFI | `.to_bytes().as_ptr()` | `.as_ptr()` сразу |

## Конвертация

### String → Bytes

```aurora
let s: String = "Hello, мир!";

// UTF-8 (по умолчанию)
let utf8: Bytes = s.to_bytes();

// Другие кодировки
let utf16: Bytes = s.encode("UTF-16LE");
let latin1: Bytes = s.encode("ISO-8859-1");
```

### Bytes → String

```aurora
let data: Bytes = read_file("data.txt");

// С проверкой (может ошибиться)
let s: String = data.to_string()?;

// Без проверки (заменяет невалидные на �)
let s: String = data.to_string_lossy();

// Из конкретной кодировки
let s: String = Bytes::decode(data, "Windows-1251")?;
```

## Частые паттерны

### Работа с файлами

```aurora
// Текстовый файл
let content: String = fs::read_to_string("config.json")?;
let config = parse_json(content);

// Бинарный файл
let data: Bytes = fs::read_bytes("image.png")?;
let image = decode_png(data);
```

### HTTP запросы

```aurora
fn handle_post(req: Request) -> Response =
  let content_type = req.header("Content-Type");

  if content_type == "application/json" then
    let body: String = req.body_as_string();
    let json = parse_json(body);
    process_json(json)
  else
    let body: Bytes = req.body_as_bytes();
    process_binary(body)
```

### Парсинг бинарного формата

```aurora
fn parse_packet(data: Bytes) -> Packet =
  let header = PacketHeader {
    type: data[0],
    length: data.read_u16_le(1),
    flags: data[3]
  };

  let payload = data.slice(4, 4 + header.length);

  Packet { header, payload }
```

### Интеграция с C библиотекой

```aurora
extern fn zlib_compress(
  input: *const u8,
  input_len: i32,
  output: *mut u8,
  output_len: *mut i32
) -> i32;

fn compress(text: String) -> Bytes =
  let input = text.to_bytes();
  let output = Bytes::with_capacity(input.size() * 2);

  let result = zlib_compress(
    input.as_ptr(),
    input.size(),
    output.as_mut_ptr(),
    &mut output_len
  );

  output.truncate(output_len);
  output
```

## Производительность

### String оптимизации

```aurora
// Плохо - много реаллокаций
let mut s = "";
for i in 0..1000 do
  s = s + "x";  // Каждый раз новая строка!

// Хорошо - с резервированием
let mut s = String::with_capacity(1000);
for i in 0..1000 do
  s.push('x');  // Эффективно!
```

### Bytes оптимизации

```aurora
// Zero-copy slice
let data: Bytes = read_large_file();
let header = data.slice(0, 16);     // Нет копирования!
let body = data.slice(16, 1024);    // Нет копирования!

// Вместо
let header = data[0..16].to_owned();  // Копирование
```

## Type Safety

```aurora
// Компилятор не даст перепутать!
fn process_text(s: String) = ...
fn process_binary(b: Bytes) = ...

let text = "Hello";
let bytes = text.to_bytes();

process_text(text);   // ✅ OK
process_text(bytes);  // ❌ Ошибка компиляции!

process_binary(bytes);// ✅ OK
process_binary(text); // ❌ Ошибка компиляции!
```

## Итог

**Для 90% случаев:**
```aurora
let s: String = "Just use String";  // Удобно как в JS!
```

**Для FFI и бинарных данных:**
```aurora
let b: Bytes = data.to_bytes();  // Точный контроль!
```

**Явная конвертация между ними - это фича, не баг!**
- Type safety
- Понятно что происходит
- Производительность только когда нужно

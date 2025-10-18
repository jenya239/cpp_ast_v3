# Предложение: Система типов строк в Aurora

## Проблема

Есть **два разных use case**:

1. **"Просто работает"** - удобство как в JS/Ruby
   - Хочется `.length`, `.substr()`, `.split()`, `.trim()`
   - Работа с символами, не байтами
   - Unicode "просто работает"

2. **Точный контроль** - для FFI и бинарных данных
   - Точно знать, что внутри (байты, кодировка)
   - Прямой доступ к памяти
   - Совместимость с C библиотеками
   - Эффективная работа с бинарными протоколами

## Решение: Два типа строк

### 1. `String` - высокоуровневый (по умолчанию)

**Для удобства, как в JS/Ruby:**

```aurora
// Создание
let s = "Hello, мир! 🌍";  // String по умолчанию

// Методы работают с СИМВОЛАМИ, не байтами
s.length();        // 14 символов (не байтов!)
s.char_at(0);      // 'H'
s.char_at(7);      // 'м'
s.char_at(13);     // '🌍'

// Операции
s.upper();         // "HELLO, МИР! 🌍"
s.lower();         // "hello, мир! 🌍"
s.trim();          // Убирает пробелы
s.split(", ");     // ["Hello", "мир! 🌍"]
s.contains("мир"); // true
s.starts_with("H");// true
s.ends_with("🌍"); // true

// Подстроки (по символам!)
s.substring(0, 5); // "Hello"
s.substring(7, 10);// "мир"

// Итерация по символам
for char in s.chars() do
  print(char)

// Конкатенация
let greeting = s + "!";
let interpolated = "Value: {s}";  // Интерполяция

// Сравнение
s == "Hello";      // false
s.compare_ignore_case("HELLO, МИР! 🌍"); // true
```

**Внутренняя реализация:**
```cpp
// Wrapper над std::string с UTF-8 библиотекой
class String {
    std::string data;  // UTF-8 байты

    // Кэш для производительности (опционально)
    mutable std::optional<size_t> cached_char_count;

    size_t length() const {
        if (!cached_char_count) {
            cached_char_count = utf8::distance(data.begin(), data.end());
        }
        return *cached_char_count;
    }

    String substring(size_t start, size_t end) const {
        auto start_it = utf8::advance(data.begin(), start);
        auto end_it = utf8::advance(start_it, end - start);
        return String(std::string(start_it, end_it));
    }
};
```

### 2. `Bytes` - низкоуровневый (для контроля)

**Для FFI, бинарных данных, точного контроля:**

```aurora
// Явное создание
let raw: Bytes = bytes("Hello");  // ASCII байты
let utf8: Bytes = "Привет".to_bytes();  // UTF-8 байты

// Методы работают с БАЙТАМИ
raw.size();        // 5 байтов
utf8.size();       // 12 байтов

// Прямой доступ к байтам
raw[0];            // 72 (ASCII 'H')
utf8[0];           // 208 (первый байт 'П' в UTF-8)

// Бинарные операции
raw.slice(0, 3);   // Первые 3 байта
raw.as_ptr();      // *const u8 для FFI

// Работа с кодировками
let latin1 = Bytes::from_encoding("Café", "ISO-8859-1");
let utf16 = Bytes::from_encoding("Hello", "UTF-16LE");

// Конвертация
utf8.to_string();         // String с проверкой валидности
utf8.to_string_lossy();   // String, заменяет невалидные байты

// Для C FFI
extern fn write_file(path: *const u8, data: *const u8, len: i32) -> i32;

let data: Bytes = load_binary_data();
write_file("out.bin".to_bytes().as_ptr(), data.as_ptr(), data.size());

// Бинарные протоколы
let packet: Bytes = bytes([0x00, 0x01, 0xFF, 0xAA]);
let header = packet.slice(0, 2);
let payload = packet.slice(2, 4);
```

**Внутренняя реализация:**
```cpp
// Просто std::vector<uint8_t> или std::string с byte semantics
class Bytes {
    std::vector<uint8_t> data;

    size_t size() const { return data.size(); }
    uint8_t operator[](size_t i) const { return data[i]; }
    const uint8_t* as_ptr() const { return data.data(); }
};
```

## Конвертация между типами

### String → Bytes

```aurora
let s: String = "Hello, мир! 🌍";

// UTF-8 (по умолчанию)
let utf8: Bytes = s.to_bytes();           // UTF-8
let utf8_bom: Bytes = s.to_bytes("UTF-8-BOM");

// Другие кодировки
let utf16: Bytes = s.encode("UTF-16LE");
let latin1: Bytes = s.encode("ISO-8859-1");  // Ошибка если есть non-Latin1!
```

### Bytes → String

```aurora
let data: Bytes = read_file("data.txt");

// С проверкой валидности
let s: String = data.to_string();  // Может вернуть Error!

// Без проверки (заменяет невалидные)
let s: String = data.to_string_lossy();  // '�' для невалидных

// Из конкретной кодировки
let s: String = Bytes::decode(data, "UTF-16LE");
let s: String = Bytes::decode(data, "ISO-8859-1");
```

## Сравнение с другими языками

### JavaScript

```javascript
// Только один тип - высокоуровневый
let s = "Hello, мир! 🌍";
s.length;              // 14 (правильно!)
s.substring(0, 5);     // "Hello"

// Для байтов - TextEncoder/TextDecoder
let encoder = new TextEncoder();
let bytes = encoder.encode(s);  // Uint8Array

// Минус: нет простого доступа к байтам
// Минус: всегда UTF-16 внутри (overhead)
```

### Ruby

```ruby
# Строки с кодировками
s = "Hello, мир! 🌍"
s.length              # 14 символов
s.bytesize            # Количество байтов
s.bytes               # Массив байтов

s.encoding            # UTF-8
s.force_encoding("ASCII-8BIT")  # Изменить интерпретацию

# Плюс: гибко
# Минус: можно случайно сломать кодировку
```

### Python 3

```python
# Два типа: str (Unicode) и bytes
s = "Hello, мир! 🌍"
len(s)                # 14 символов
s[0]                  # 'H'

# bytes - отдельный тип
b = s.encode('utf-8')  # bytes
len(b)                # Количество байтов
b[0]                  # Числовой байт

# Плюс: чёткое разделение
# Плюс: type safety
```

### Rust

```rust
// Два типа: String (UTF-8) и Vec<u8> (байты)
let s = String::from("Hello, мир! 🌍");
s.len()               // БАЙТЫ (не символы!)
s.chars().count()     // Символы

let bytes: Vec<u8> = s.into_bytes();
bytes.len()           // Байты

// Плюс: type safety
// Плюс: zero-cost
// Минус: .len() на String - это байты (путаница!)
```

### Aurora (предложение)

```aurora
// String - высокоуровневый
let s: String = "Hello, мир! 🌍";
s.length();           // 14 символов (как JS/Python)
s.char_at(0);         // 'H'

// Bytes - низкоуровневый
let b: Bytes = s.to_bytes();
b.size();             // Байты
b[0];                 // Числовой байт

// Плюс: чёткое разделение
// Плюс: удобство по умолчанию
// Плюс: контроль когда нужно
```

## Примеры использования

### Use Case 1: Обработка текста (String)

```aurora
fn process_user_input(input: String) -> String =
  let trimmed = input.trim();
  let lower = trimmed.lower();

  if lower.contains("bad_word") then
    "***"
  else
    trimmed

fn format_name(first: String, last: String) -> String =
  "{first.capitalize()} {last.capitalize()}"

fn count_words(text: String) -> i32 =
  text.split(" ").length()
```

### Use Case 2: FFI с C библиотекой (Bytes)

```aurora
// C функция
extern fn sqlite3_exec(
  db: *const u8,
  sql: *const u8,
  callback: *const u8,
  arg: *const u8,
  errmsg: *const *const u8
) -> i32;

fn execute_sql(db: Database, query: String) -> Result<(), String> =
  // Конвертируем в null-terminated C строку
  let sql_bytes = query.to_bytes() + bytes([0]);  // Добавляем \0

  let result = sqlite3_exec(
    db.handle(),
    sql_bytes.as_ptr(),
    null(),
    null(),
    null()
  );

  if result == 0 then
    Ok(())
  else
    Err("SQL error")
```

### Use Case 3: Бинарный протокол (Bytes)

```aurora
type PacketHeader = {
  magic: u32,
  version: u8,
  length: u16
}

fn parse_packet(data: Bytes) -> Result<PacketHeader, String> =
  if data.size() < 7 then
    return Err("Packet too small");

  let magic = read_u32_be(data, 0);
  let version = data[4];
  let length = read_u16_be(data, 5);

  Ok(PacketHeader { magic, version, length })

fn read_u32_be(data: Bytes, offset: i32) -> u32 =
  (data[offset] << 24) |
  (data[offset + 1] << 16) |
  (data[offset + 2] << 8) |
  data[offset + 3]
```

### Use Case 4: Работа с файлами

```aurora
// Текстовые файлы - String
fn read_config(path: String) -> Config =
  let content = fs::read_to_string(path)?;  // String автоматически
  parse_json(content)

// Бинарные файлы - Bytes
fn read_image(path: String) -> Image =
  let data = fs::read_bytes(path)?;  // Bytes
  decode_png(data)

// Смешанный режим - контроль кодировки
fn read_legacy_file(path: String) -> String =
  let bytes = fs::read_bytes(path)?;
  // Файл в Windows-1251
  Bytes::decode(bytes, "Windows-1251")
```

## API предложения

### String API (высокоуровневый)

```aurora
type String = {
  // Создание
  from_chars(chars: [Char]) -> String

  // Информация (о символах!)
  length() -> i32                    // Количество символов
  is_empty() -> bool

  // Доступ к символам
  char_at(index: i32) -> Char
  chars() -> Iterator<Char>

  // Подстроки (по символам!)
  substring(start: i32, end: i32) -> String
  slice(range: Range) -> String      // s.slice(0..5)

  // Поиск
  contains(needle: String) -> bool
  starts_with(prefix: String) -> bool
  ends_with(suffix: String) -> bool
  index_of(needle: String) -> Option<i32>

  // Трансформации
  upper() -> String
  lower() -> String
  trim() -> String
  trim_start() -> String
  trim_end() -> String

  // Разделение/объединение
  split(delimiter: String) -> [String]
  lines() -> [String]
  join(strings: [String], separator: String) -> String

  // Замена
  replace(from: String, to: String) -> String
  replace_all(from: String, to: String) -> String

  // Сравнение
  compare_ignore_case(other: String) -> bool

  // Конвертация
  to_bytes() -> Bytes                // UTF-8
  encode(encoding: String) -> Bytes  // Конкретная кодировка

  // Форматирование
  format(args: ...) -> String        // "Hello, {name}!"
}
```

### Bytes API (низкоуровневый)

```aurora
type Bytes = {
  // Создание
  from_array(bytes: [u8]) -> Bytes
  from_encoding(text: String, encoding: String) -> Bytes

  // Информация (о байтах!)
  size() -> i32                      // Количество байтов
  is_empty() -> bool

  // Доступ к байтам
  [index: i32] -> u8                 // Индексация
  slice(start: i32, end: i32) -> Bytes

  // Указатели (для FFI)
  as_ptr() -> *const u8
  as_mut_ptr() -> *mut u8

  // Конвертация
  to_string() -> Result<String, Error>      // С проверкой UTF-8
  to_string_lossy() -> String               // С заменой невалидных
  decode(encoding: String) -> Result<String, Error>

  // Бинарные операции
  read_u8(offset: i32) -> u8
  read_u16_le(offset: i32) -> u16
  read_u16_be(offset: i32) -> u16
  read_u32_le(offset: i32) -> u32
  read_u32_be(offset: i32) -> u32
  read_u64_le(offset: i32) -> u64
  read_u64_be(offset: i32) -> u64
}
```

## Реализация

### Фаза 1: Минимум для MVP

```aurora
// String - просто std::string с методами для символов
type String = std::string + utf8_wrapper

// Bytes - просто std::vector<uint8_t>
type Bytes = std::vector<uint8_t>

// Базовые методы
String::length()      // utf8::distance()
String::to_bytes()    // copy to vector<uint8_t>
Bytes::to_string()    // validate + copy
```

### Фаза 2: Оптимизации

```cpp
// String с кэшированием
class String {
    std::string data;
    mutable std::optional<size_t> char_count_cache;

    size_t length() const {
        if (!char_count_cache) {
            char_count_cache = utf8::distance(data.begin(), data.end());
        }
        return *char_count_cache;
    }
};

// Bytes с zero-copy views
class Bytes {
    std::shared_ptr<std::vector<uint8_t>> data;
    size_t offset = 0;
    size_t len;

    Bytes slice(size_t start, size_t end) {
        // No copy! Just create view
        return Bytes{data, offset + start, end - start};
    }
};
```

### Фаза 3: Полный API

- Все методы из предложенного API
- Интеграция с ICU для Unicode операций
- Оптимизированные алгоритмы
- Zero-copy где возможно

## Преимущества предложения

✅ **Удобство по умолчанию**: String работает с символами как в JS/Ruby
✅ **Контроль когда нужно**: Bytes для FFI и бинарных данных
✅ **Type safety**: Компилятор не даст перепутать
✅ **Производительность**: Можно оптимизировать под каждый use case
✅ **Явная конвертация**: Невозможны случайные ошибки с кодировками
✅ **FFI friendly**: Bytes напрямую даёт указатели
✅ **Совместимость**: String → std::string, Bytes → std::vector<uint8_t>

## Примеры из реальной жизни

### Web сервер

```aurora
fn handle_request(req: Request) -> Response =
  // String для HTTP заголовков
  let content_type: String = req.header("Content-Type");

  if content_type.starts_with("application/json") then
    // String для JSON
    let body: String = req.body_as_string();
    let data = parse_json(body);
    process_json(data)
  else if content_type.starts_with("application/octet-stream") then
    // Bytes для бинарных данных
    let body: Bytes = req.body_as_bytes();
    process_binary(body)
```

### Парсер бинарного формата

```aurora
fn parse_png(data: Bytes) -> Result<Image, Error> =
  // Проверяем магическое число (байты)
  if data.slice(0, 8) != PNG_MAGIC then
    return Err("Not a PNG file");

  // Читаем чанки
  let mut offset = 8;
  let chunks = [];

  while offset < data.size() do
    let length = data.read_u32_be(offset);
    let chunk_type = data.slice(offset + 4, offset + 8);
    let chunk_data = data.slice(offset + 8, offset + 8 + length);

    // Для текстовых чанков конвертируем в String
    if chunk_type == bytes("tEXt") then
      let text = chunk_data.to_string_lossy();
      chunks.push(TextChunk(text));

    offset += 12 + length;

  Ok(Image { chunks })
```

## Итог

**Два типа строк решают обе проблемы:**

1. **`String`** - "просто работает"
   - Как в JS/Ruby/Python
   - Методы работают с символами
   - Unicode корректно

2. **`Bytes`** - точный контроль
   - Для FFI с C библиотеками
   - Для бинарных протоколов
   - Для работы с кодировками

**Явная конвертация между ними:**
- Type safety
- Нельзя случайно перепутать
- Производительность (только когда нужно)

**Это как в Python 3 и Rust - лучшие практики!** 🎯

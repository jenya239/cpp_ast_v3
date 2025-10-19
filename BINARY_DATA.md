# Binary Data Support in Aurora

Complete binary data handling for buffers, protocols, and binary formats.

## Overview

Aurora provides comprehensive binary data support through three main components:

1. **Buffer** - Mutable byte buffer with position tracking
2. **BinaryReader** - Type-safe reading with endianness support
3. **BinaryWriter** - Type-safe writing with endianness support

## Quick Start

```cpp
#include "runtime/aurora_buffer.hpp"
using namespace aurora;

// Create buffer and write data
Buffer buf;
BinaryWriter writer(buf, Endian::Little);

writer.write_u32(0x12345678);
writer.write_string(String("Hello"));

// Read data back
BinaryReader reader(buf, Endian::Little);
uint32_t value = reader.read_u32();
String text = reader.read_string(5);
```

## Buffer Class

Mutable byte buffer with automatic memory management and position tracking.

### Construction

```cpp
Buffer();                        // Empty buffer
Buffer(size_t capacity);         // Pre-allocated
Buffer(const Bytes& data);       // From Bytes
Buffer(const uint8_t* data, size_t len);  // From raw data
```

### Capacity Management

```cpp
size_t size() const;            // Current data size
size_t capacity() const;        // Total capacity
size_t remaining() const;       // Bytes left from position
void reserve(size_t n);         // Reserve capacity
void resize(size_t n);          // Resize data
void clear();                   // Clear all data
```

### Position Tracking

```cpp
size_t position() const;        // Current position
void set_position(size_t pos);  // Set position
void skip(size_t n);            // Advance position
void reset();                   // Position = 0
```

### Data Access

```cpp
uint8_t* data();                    // Mutable pointer
const uint8_t* data() const;        // Const pointer
uint8_t& operator[](size_t i);      // Mutable access
uint8_t operator[](size_t i) const; // Const access
```

### Appending Data

```cpp
void append(uint8_t byte);
void append(const uint8_t* data, size_t len);
void append(const Bytes& bytes);
```

### Conversion

```cpp
Bytes to_bytes() const;                 // To immutable Bytes
static Buffer from_bytes(const Bytes&); // From Bytes
```

## BinaryReader Class

Type-safe reading from buffer with endianness support.

### Construction

```cpp
BinaryReader(Buffer& buf, Endian endian = Endian::Little);
```

### Position Control

```cpp
size_t position() const;
void set_position(size_t pos);
size_t remaining() const;
bool has_remaining(size_t n) const;
void skip(size_t n);
```

### Integer Reads

```cpp
uint8_t read_u8();
int8_t read_i8();
uint16_t read_u16();   // With endianness conversion
int16_t read_i16();
uint32_t read_u32();
int32_t read_i32();
uint64_t read_u64();
int64_t read_i64();
```

### Float Reads

```cpp
float read_f32();      // IEEE 754 single precision
double read_f64();     // IEEE 754 double precision
```

### Bytes/String Reads

```cpp
Bytes read_bytes(size_t n);           // Read n bytes
String read_string(size_t n);         // Read UTF-8 string
String read_cstring();                // Read null-terminated string
```

### Length-Prefixed Reads

Common pattern: u32 length followed by data.

```cpp
Bytes read_length_prefixed();         // u32 length + bytes
String read_length_prefixed_string(); // u32 length + UTF-8 string
```

### Varint Reads

Compact integer encoding (LEB128, like Protobuf).

```cpp
uint64_t read_varint();           // Unsigned varint
int64_t read_signed_varint();     // Signed varint (ZigZag encoded)
```

## BinaryWriter Class

Type-safe writing to buffer with endianness support.

### Construction

```cpp
BinaryWriter(Buffer& buf, Endian endian = Endian::Little);
```

### Position

```cpp
size_t position() const;  // Returns buffer size (write position)
```

### Integer Writes

```cpp
void write_u8(uint8_t val);
void write_i8(int8_t val);
void write_u16(uint16_t val);  // With endianness conversion
void write_i16(int16_t val);
void write_u32(uint32_t val);
void write_i32(int32_t val);
void write_u64(uint64_t val);
void write_i64(int64_t val);
```

### Float Writes

```cpp
void write_f32(float val);     // IEEE 754 single precision
void write_f64(double val);    // IEEE 754 double precision
```

### Bytes/String Writes

```cpp
void write_bytes(const Bytes& data);
void write_string(const String& str);
void write_cstring(const String& str);  // With null terminator
```

### Length-Prefixed Writes

```cpp
void write_length_prefixed(const Bytes& data);
void write_length_prefixed_string(const String& str);
```

### Varint Writes

```cpp
void write_varint(uint64_t val);
void write_signed_varint(int64_t val);
```

## Endianness Support

### Endian Enum

```cpp
enum class Endian {
    Little,  // x86, ARM (most common)
    Big,     // Network byte order, some CPUs
    Native   // Use system endianness
};
```

### Endianness Utilities

```cpp
namespace endian {
    // Detect native endianness
    Endian native();  // Returns Little or Big
    
    // Byte swapping
    uint16_t swap16(uint16_t val);
    uint32_t swap32(uint32_t val);
    uint64_t swap64(uint64_t val);
    
    // Convert to specific endianness
    uint16_t to_little(uint16_t val);
    uint16_t to_big(uint16_t val);
    uint32_t to_little(uint32_t val);
    uint32_t to_big(uint32_t val);
    uint64_t to_little(uint64_t val);
    uint64_t to_big(uint64_t val);
    
    // Convert from specific endianness
    uint16_t from_little(uint16_t val);
    uint16_t from_big(uint16_t val);
    // ... same for 32, 64
}
```

### Endianness Examples

```cpp
// Network protocols typically use Big Endian
BinaryWriter net_writer(buf, Endian::Big);
net_writer.write_u32(0x12345678);  // Writes: 12 34 56 78

// File formats vary (BMP uses Little Endian)
BinaryWriter bmp_writer(buf, Endian::Little);
bmp_writer.write_u32(0x12345678);  // Writes: 78 56 34 12
```

## Common Patterns

### 1. Reading a Binary File Format

```cpp
// Example: BMP file header
Buffer buf = /* read from file */;
BinaryReader reader(buf, Endian::Little);  // BMP is little-endian

// Read signature
uint16_t signature = reader.read_u16();
if (signature != 0x4D42) {  // "BM"
    throw std::runtime_error("Not a BMP file");
}

// Read header fields
uint32_t file_size = reader.read_u32();
reader.skip(4);  // Reserved
uint32_t data_offset = reader.read_u32();
```

### 2. Writing a Network Protocol

```cpp
Buffer buf;
BinaryWriter writer(buf, Endian::Big);  // Network byte order

// Protocol header
writer.write_u32(0x12345678);  // Magic number
writer.write_u16(1);           // Version
writer.write_u16(0x01);        // Message type

// Payload
writer.write_length_prefixed_string(String("Hello"));

// Send over network
send(buf.to_bytes());
```

### 3. Structured Binary Data

```cpp
// Writing
Buffer buf;
BinaryWriter writer(buf);

writer.write_u8(0x01);  // Type
writer.write_u32(123);  // ID
writer.write_string(String("Name"));
writer.write_f64(3.14159);

// Reading
BinaryReader reader(buf);
uint8_t type = reader.read_u8();
uint32_t id = reader.read_u32();
String name = reader.read_string(4);
double value = reader.read_f64();
```

### 4. Varint Encoding (Space-Efficient)

```cpp
Buffer buf;
BinaryWriter writer(buf);

// Small numbers use fewer bytes
writer.write_varint(1);        // 1 byte
writer.write_varint(127);      // 1 byte
writer.write_varint(128);      // 2 bytes
writer.write_varint(16383);    // 2 bytes
writer.write_varint(16384);    // 3 bytes
writer.write_varint(1000000);  // 3 bytes

// vs fixed uint64_t which always uses 8 bytes
std::cout << "Varint size: " << buf.size() << " bytes\n";
std::cout << "vs uint64_t: " << (6 * 8) << " bytes\n";
```

### 5. Length-Prefixed Data

```cpp
// Writing
Buffer buf;
BinaryWriter writer(buf);

writer.write_length_prefixed_string(String("First message"));
writer.write_length_prefixed_string(String("Second message"));

// Reading
BinaryReader reader(buf);

String msg1 = reader.read_length_prefixed_string();
String msg2 = reader.read_length_prefixed_string();
```

### 6. Parsing Multiple Messages from Stream

```cpp
BinaryReader reader(stream_buf, Endian::Big);

while (reader.has_remaining(HEADER_SIZE)) {
    uint32_t magic = reader.read_u32();
    if (magic != EXPECTED_MAGIC) break;
    
    uint32_t length = reader.read_u32();
    Bytes payload = reader.read_bytes(length);
    
    // Process message...
}
```

## Examples

See:
- **[examples/16_buffer_basics.cpp](examples/16_buffer_basics.cpp)** - All buffer operations
- **[examples/17_bmp_parser.cpp](examples/17_bmp_parser.cpp)** - Real binary format (BMP)
- **[examples/18_network_protocol.cpp](examples/18_network_protocol.cpp)** - Custom protocol

## Performance Notes

### Zero-Copy Operations

Buffer uses `std::vector<uint8_t>` internally, which provides:
- Contiguous memory
- Efficient growth (amortized O(1) append)
- RAII memory management

### Endianness Conversion

- Conversion only happens for multi-byte types (u16, u32, u64, floats)
- u8/i8 reads/writes are direct - no conversion overhead
- Native endian operations have zero overhead

### Varint Performance

- Reading/writing: O(bytes) where bytes = ceil(log₁₂₈(value))
- Space efficient for small numbers
- Typical savings: 50-75% for most real-world data

## Integration with Aurora Types

### Buffer ↔ Bytes

```cpp
Bytes bytes = buffer.to_bytes();       // Buffer → Bytes (copy)
Buffer buf = Buffer::from_bytes(bytes); // Bytes → Buffer (copy)
```

### String Support

```cpp
String text("Hello");
writer.write_string(text);  // Writes UTF-8 bytes

String read = reader.read_string(5);  // Reads 5 bytes as UTF-8
```

## Error Handling

All read operations validate buffer bounds:

```cpp
try {
    uint32_t val = reader.read_u32();
} catch (const std::out_of_range& e) {
    // Not enough data in buffer
}
```

Common exceptions:
- `std::out_of_range` - Read past end of buffer
- `std::runtime_error` - Invalid varint, protocol errors

## Compilation

```bash
# Include aurora_buffer.hpp
g++ -std=c++17 -I. your_file.cpp runtime/aurora_string.cpp -o your_program
```

Note: `aurora_buffer.hpp` is header-only, but depends on `aurora_string.cpp`.

## Use Cases

### ✅ Perfect For

- Network protocols (TCP/UDP packets)
- Binary file formats (images, audio, video)
- Serialization/deserialization
- FFI with C libraries
- Embedded systems
- Game networking
- Database wire protocols

### ⚠️ Not Ideal For

- Text-based formats (use String instead)
- JSON/XML (use dedicated parsers)
- Large file streaming (use streaming I/O)

## Future Enhancements

Planned features:

1. **Bit-level operations** - Read/write individual bits
2. **CRC/Checksum helpers** - Common checksums (CRC32, Adler32)
3. **Compression integration** - zlib, LZ4 support
4. **Memory mapping** - mmap for large files
5. **Format descriptors** - Declarative binary format specs
6. **Alignment helpers** - Padding for structure alignment

## Summary

Aurora's binary data support provides:

✅ Type-safe read/write operations  
✅ Automatic endianness handling  
✅ Position tracking  
✅ Varint encoding (space-efficient)  
✅ Length-prefixed patterns  
✅ Zero-copy where possible  
✅ Exception-safe RAII  
✅ Production-ready for real protocols

Perfect for network protocols, file formats, and binary data processing!

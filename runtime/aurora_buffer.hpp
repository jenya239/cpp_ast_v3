#pragma once

#include "aurora_string.hpp"
#include <vector>
#include <cstring>
#include <stdexcept>
#include <cstdint>

namespace aurora {

// ============================================================================
// Endianness Support
// ============================================================================

enum class Endian {
    Little,
    Big,
    Native
};

namespace endian {
    // Byte swapping
    inline uint16_t swap16(uint16_t val) {
        return (val << 8) | (val >> 8);
    }

    inline uint32_t swap32(uint32_t val) {
        return ((val & 0xFF000000) >> 24) |
               ((val & 0x00FF0000) >> 8)  |
               ((val & 0x0000FF00) << 8)  |
               ((val & 0x000000FF) << 24);
    }

    inline uint64_t swap64(uint64_t val) {
        return ((val & 0xFF00000000000000ULL) >> 56) |
               ((val & 0x00FF000000000000ULL) >> 40) |
               ((val & 0x0000FF0000000000ULL) >> 24) |
               ((val & 0x000000FF00000000ULL) >> 8)  |
               ((val & 0x00000000FF000000ULL) << 8)  |
               ((val & 0x0000000000FF0000ULL) << 24) |
               ((val & 0x000000000000FF00ULL) << 40) |
               ((val & 0x00000000000000FFULL) << 56);
    }

    // Detect native endianness
    inline Endian native() {
        uint16_t test = 0x0001;
        uint8_t* bytes = reinterpret_cast<uint8_t*>(&test);
        return (bytes[0] == 0x01) ? Endian::Little : Endian::Big;
    }

    // Convert to specific endianness
    inline uint16_t to_little(uint16_t val) {
        return (native() == Endian::Little) ? val : swap16(val);
    }

    inline uint16_t to_big(uint16_t val) {
        return (native() == Endian::Big) ? val : swap16(val);
    }

    inline uint32_t to_little(uint32_t val) {
        return (native() == Endian::Little) ? val : swap32(val);
    }

    inline uint32_t to_big(uint32_t val) {
        return (native() == Endian::Big) ? val : swap32(val);
    }

    inline uint64_t to_little(uint64_t val) {
        return (native() == Endian::Little) ? val : swap64(val);
    }

    inline uint64_t to_big(uint64_t val) {
        return (native() == Endian::Big) ? val : swap64(val);
    }

    // Convert from specific endianness
    inline uint16_t from_little(uint16_t val) { return to_little(val); }
    inline uint16_t from_big(uint16_t val) { return to_big(val); }
    inline uint32_t from_little(uint32_t val) { return to_little(val); }
    inline uint32_t from_big(uint32_t val) { return to_big(val); }
    inline uint64_t from_little(uint64_t val) { return to_little(val); }
    inline uint64_t from_big(uint64_t val) { return to_big(val); }
}

// ============================================================================
// Buffer - Mutable byte buffer with position tracking
// ============================================================================

class Buffer {
private:
    std::vector<uint8_t> data_;
    size_t position_;

public:
    // Construction
    Buffer() : data_(), position_(0) {}

    explicit Buffer(size_t capacity) : data_(), position_(0) {
        data_.reserve(capacity);
    }

    Buffer(const Bytes& bytes) : data_(bytes.size()), position_(0) {
        std::memcpy(data_.data(), bytes.as_ptr(), bytes.size());
    }

    Buffer(const uint8_t* data, size_t len) : data_(data, data + len), position_(0) {}

    // Capacity
    size_t size() const { return data_.size(); }
    size_t capacity() const { return data_.capacity(); }
    size_t remaining() const { return position_ < data_.size() ? data_.size() - position_ : 0; }

    void reserve(size_t n) { data_.reserve(n); }
    void resize(size_t n) { data_.resize(n); }
    void clear() { data_.clear(); position_ = 0; }

    // Position
    size_t position() const { return position_; }

    void set_position(size_t pos) {
        if (pos > data_.size()) {
            throw std::out_of_range("Buffer position out of range");
        }
        position_ = pos;
    }

    void skip(size_t n) {
        if (position_ + n > data_.size()) {
            throw std::out_of_range("Buffer skip out of range");
        }
        position_ += n;
    }

    void reset() { position_ = 0; }

    // Raw access
    uint8_t* data() { return data_.data(); }
    const uint8_t* data() const { return data_.data(); }

    uint8_t& operator[](size_t i) { return data_[i]; }
    uint8_t operator[](size_t i) const { return data_[i]; }

    // Append data
    void append(uint8_t byte) {
        data_.push_back(byte);
    }

    void append(const uint8_t* data, size_t len) {
        data_.insert(data_.end(), data, data + len);
    }

    void append(const Bytes& bytes) {
        append(bytes.as_ptr(), bytes.size());
    }

    // Conversion
    Bytes to_bytes() const {
        return Bytes(data_.data(), data_.size());
    }

    static Buffer from_bytes(const Bytes& bytes) {
        return Buffer(bytes);
    }
};

// ============================================================================
// BinaryReader - Read typed data from buffer
// ============================================================================

class BinaryReader {
private:
    Buffer& buffer_;
    Endian endian_;

    void check_remaining(size_t n) const {
        if (buffer_.remaining() < n) {
            throw std::out_of_range("Not enough data in buffer");
        }
    }

    template<typename T>
    T read_int() {
        check_remaining(sizeof(T));
        T val;
        std::memcpy(&val, buffer_.data() + buffer_.position(), sizeof(T));
        buffer_.skip(sizeof(T));

        // Apply endianness conversion
        if constexpr (sizeof(T) == 2) {
            if (endian_ == Endian::Little) {
                val = endian::from_little(static_cast<uint16_t>(val));
            } else if (endian_ == Endian::Big) {
                val = endian::from_big(static_cast<uint16_t>(val));
            }
        } else if constexpr (sizeof(T) == 4) {
            if (endian_ == Endian::Little) {
                val = endian::from_little(static_cast<uint32_t>(val));
            } else if (endian_ == Endian::Big) {
                val = endian::from_big(static_cast<uint32_t>(val));
            }
        } else if constexpr (sizeof(T) == 8) {
            if (endian_ == Endian::Little) {
                val = endian::from_little(static_cast<uint64_t>(val));
            } else if (endian_ == Endian::Big) {
                val = endian::from_big(static_cast<uint64_t>(val));
            }
        }

        return val;
    }

public:
    BinaryReader(Buffer& buf, Endian endian = Endian::Little)
        : buffer_(buf), endian_(endian) {}

    // Position
    size_t position() const { return buffer_.position(); }
    void set_position(size_t pos) { buffer_.set_position(pos); }
    size_t remaining() const { return buffer_.remaining(); }
    bool has_remaining(size_t n) const { return buffer_.remaining() >= n; }
    void skip(size_t n) { buffer_.skip(n); }

    // Integer reads
    uint8_t read_u8() {
        check_remaining(1);
        uint8_t val = buffer_[buffer_.position()];
        buffer_.skip(1);
        return val;
    }

    int8_t read_i8() {
        return static_cast<int8_t>(read_u8());
    }

    uint16_t read_u16() { return read_int<uint16_t>(); }
    int16_t read_i16() { return read_int<int16_t>(); }
    uint32_t read_u32() { return read_int<uint32_t>(); }
    int32_t read_i32() { return read_int<int32_t>(); }
    uint64_t read_u64() { return read_int<uint64_t>(); }
    int64_t read_i64() { return read_int<int64_t>(); }

    // Float reads
    float read_f32() {
        uint32_t bits = read_u32();
        float val;
        std::memcpy(&val, &bits, sizeof(float));
        return val;
    }

    double read_f64() {
        uint64_t bits = read_u64();
        double val;
        std::memcpy(&val, &bits, sizeof(double));
        return val;
    }

    // Bytes/String reads
    Bytes read_bytes(size_t n) {
        check_remaining(n);
        Bytes result(buffer_.data() + buffer_.position(), n);
        buffer_.skip(n);
        return result;
    }

    String read_string(size_t n) {
        auto bytes = read_bytes(n);
        return String::from_bytes(bytes);
    }

    String read_cstring() {
        size_t start = buffer_.position();
        size_t len = 0;

        while (buffer_.position() < buffer_.size()) {
            if (buffer_[buffer_.position()] == 0) {
                buffer_.skip(1);  // Skip null terminator
                break;
            }
            buffer_.skip(1);
            len++;
        }

        return String::from_bytes(Bytes(buffer_.data() + start, len));
    }

    // Length-prefixed reads
    Bytes read_length_prefixed() {
        uint32_t len = read_u32();
        return read_bytes(len);
    }

    String read_length_prefixed_string() {
        auto bytes = read_length_prefixed();
        return String::from_bytes(bytes);
    }

    // Varint (LEB128 encoding, like Protobuf)
    uint64_t read_varint() {
        uint64_t result = 0;
        int shift = 0;

        while (true) {
            uint8_t byte = read_u8();
            result |= static_cast<uint64_t>(byte & 0x7F) << shift;

            if ((byte & 0x80) == 0) break;

            shift += 7;
            if (shift >= 64) {
                throw std::runtime_error("Varint too long");
            }
        }

        return result;
    }

    int64_t read_signed_varint() {
        uint64_t val = read_varint();
        // ZigZag decoding
        return (val >> 1) ^ -(val & 1);
    }
};

// ============================================================================
// BinaryWriter - Write typed data to buffer
// ============================================================================

class BinaryWriter {
private:
    Buffer& buffer_;
    Endian endian_;

    template<typename T>
    void write_int(T val) {
        // Apply endianness conversion
        if constexpr (sizeof(T) == 2) {
            if (endian_ == Endian::Little) {
                val = endian::to_little(static_cast<uint16_t>(val));
            } else if (endian_ == Endian::Big) {
                val = endian::to_big(static_cast<uint16_t>(val));
            }
        } else if constexpr (sizeof(T) == 4) {
            if (endian_ == Endian::Little) {
                val = endian::to_little(static_cast<uint32_t>(val));
            } else if (endian_ == Endian::Big) {
                val = endian::to_big(static_cast<uint32_t>(val));
            }
        } else if constexpr (sizeof(T) == 8) {
            if (endian_ == Endian::Little) {
                val = endian::to_little(static_cast<uint64_t>(val));
            } else if (endian_ == Endian::Big) {
                val = endian::to_big(static_cast<uint64_t>(val));
            }
        }

        const uint8_t* bytes = reinterpret_cast<const uint8_t*>(&val);
        buffer_.append(bytes, sizeof(T));
    }

public:
    BinaryWriter(Buffer& buf, Endian endian = Endian::Little)
        : buffer_(buf), endian_(endian) {}

    // Position
    size_t position() const { return buffer_.size(); }

    // Integer writes
    void write_u8(uint8_t val) {
        buffer_.append(val);
    }

    void write_i8(int8_t val) {
        write_u8(static_cast<uint8_t>(val));
    }

    void write_u16(uint16_t val) { write_int(val); }
    void write_i16(int16_t val) { write_int(val); }
    void write_u32(uint32_t val) { write_int(val); }
    void write_i32(int32_t val) { write_int(val); }
    void write_u64(uint64_t val) { write_int(val); }
    void write_i64(int64_t val) { write_int(val); }

    // Float writes
    void write_f32(float val) {
        uint32_t bits;
        std::memcpy(&bits, &val, sizeof(float));
        write_u32(bits);
    }

    void write_f64(double val) {
        uint64_t bits;
        std::memcpy(&bits, &val, sizeof(double));
        write_u64(bits);
    }

    // Bytes/String writes
    void write_bytes(const Bytes& data) {
        buffer_.append(data);
    }

    void write_string(const String& str) {
        write_bytes(str.to_bytes());
    }

    void write_cstring(const String& str) {
        write_string(str);
        write_u8(0);  // Null terminator
    }

    // Length-prefixed writes
    void write_length_prefixed(const Bytes& data) {
        write_u32(static_cast<uint32_t>(data.size()));
        write_bytes(data);
    }

    void write_length_prefixed_string(const String& str) {
        auto bytes = str.to_bytes();
        write_length_prefixed(bytes);
    }

    // Varint (LEB128 encoding)
    void write_varint(uint64_t val) {
        while (val >= 0x80) {
            write_u8(static_cast<uint8_t>((val & 0x7F) | 0x80));
            val >>= 7;
        }
        write_u8(static_cast<uint8_t>(val & 0x7F));
    }

    void write_signed_varint(int64_t val) {
        // ZigZag encoding
        uint64_t encoded = (val << 1) ^ (val >> 63);
        write_varint(encoded);
    }
};

} // namespace aurora

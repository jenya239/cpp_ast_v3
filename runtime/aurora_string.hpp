#ifndef AURORA_STRING_HPP
#define AURORA_STRING_HPP

#include <string>
#include <vector>
#include <cstdint>
#include <stdexcept>

namespace aurora {

// Forward declarations
class Bytes;

// Aurora String class - high-level, character-oriented, UTF-8 aware
class String {
private:
    std::string data_;

    // Helper: count UTF-8 characters in a string
    static size_t utf8_length(const std::string& str);

    // Helper: get byte index of nth character
    static size_t utf8_char_index(const std::string& str, size_t char_pos);

    // Helper: get one UTF-8 character at position
    static std::string utf8_char_at(const std::string& str, size_t char_pos);

public:
    // Constructors
    String() : data_() {}
    String(const char* str) : data_(str) {}
    String(const std::string& str) : data_(str) {}
    String(std::string&& str) : data_(std::move(str)) {}

    // Copy/Move
    String(const String&) = default;
    String(String&&) = default;
    String& operator=(const String&) = default;
    String& operator=(String&&) = default;

    // Basic properties
    size_t length() const { return utf8_length(data_); }
    size_t byte_size() const { return data_.size(); }
    bool is_empty() const { return data_.empty(); }

    // Character access
    std::string char_at(size_t index) const {
        return utf8_char_at(data_, index);
    }

    // Substrings (by character positions, not bytes)
    String substring(size_t start) const;
    String substring(size_t start, size_t length) const;

    // Case conversion
    String upper() const;
    String lower() const;

    // Trimming
    String trim() const;
    String trim_start() const;
    String trim_end() const;

    // Splitting
    std::vector<String> split(const String& delimiter) const;

    // Searching
    bool contains(const String& substring) const {
        return data_.find(substring.data_) != std::string::npos;
    }

    bool starts_with(const String& prefix) const {
        if (prefix.byte_size() > byte_size()) return false;
        return data_.compare(0, prefix.byte_size(), prefix.data_) == 0;
    }

    bool ends_with(const String& suffix) const {
        if (suffix.byte_size() > byte_size()) return false;
        return data_.compare(byte_size() - suffix.byte_size(),
                            suffix.byte_size(), suffix.data_) == 0;
    }

    // Concatenation
    String operator+(const String& other) const {
        return String(data_ + other.data_);
    }

    String& operator+=(const String& other) {
        data_ += other.data_;
        return *this;
    }

    // Comparison
    bool operator==(const String& other) const { return data_ == other.data_; }
    bool operator!=(const String& other) const { return data_ != other.data_; }
    bool operator<(const String& other) const { return data_ < other.data_; }
    bool operator>(const String& other) const { return data_ > other.data_; }
    bool operator<=(const String& other) const { return data_ <= other.data_; }
    bool operator>=(const String& other) const { return data_ >= other.data_; }

    // Conversion to/from Bytes
    Bytes to_bytes() const;
    static String from_bytes(const Bytes& bytes);

    // Access to underlying std::string (for C++ interop)
    const std::string& as_std_string() const { return data_; }
    const char* c_str() const { return data_.c_str(); }
};

// Aurora Bytes class - low-level, byte-oriented, FFI-friendly
class Bytes {
private:
    std::vector<uint8_t> data_;

public:
    // Constructors
    Bytes() : data_() {}
    Bytes(const std::vector<uint8_t>& bytes) : data_(bytes) {}
    Bytes(std::vector<uint8_t>&& bytes) : data_(std::move(bytes)) {}
    Bytes(const uint8_t* ptr, size_t size) : data_(ptr, ptr + size) {}

    // Iterator constructor
    template<typename Iterator>
    Bytes(Iterator begin, Iterator end) : data_(begin, end) {}

    // Copy/Move
    Bytes(const Bytes&) = default;
    Bytes(Bytes&&) = default;
    Bytes& operator=(const Bytes&) = default;
    Bytes& operator=(Bytes&&) = default;

    // Basic properties
    size_t size() const { return data_.size(); }
    bool is_empty() const { return data_.empty(); }

    // Element access
    uint8_t operator[](size_t index) const {
        if (index >= data_.size()) {
            throw std::out_of_range("Bytes index out of range");
        }
        return data_[index];
    }

    uint8_t& operator[](size_t index) {
        if (index >= data_.size()) {
            throw std::out_of_range("Bytes index out of range");
        }
        return data_[index];
    }

    // Slicing
    Bytes slice(size_t start) const {
        if (start > data_.size()) {
            throw std::out_of_range("Bytes slice start out of range");
        }
        return Bytes(data_.begin() + start, data_.end());
    }

    Bytes slice(size_t start, size_t length) const {
        if (start > data_.size() || start + length > data_.size()) {
            throw std::out_of_range("Bytes slice out of range");
        }
        return Bytes(data_.begin() + start, data_.begin() + start + length);
    }

    // Raw pointer access (for FFI)
    const uint8_t* as_ptr() const { return data_.data(); }
    uint8_t* as_mut_ptr() { return data_.data(); }

    // Comparison
    bool operator==(const Bytes& other) const { return data_ == other.data_; }
    bool operator!=(const Bytes& other) const { return data_ != other.data_; }

    // Conversion to/from String
    String to_string() const {
        return String(std::string(data_.begin(), data_.end()));
    }

    static Bytes from_string(const String& str) {
        const std::string& s = str.as_std_string();
        return Bytes(reinterpret_cast<const uint8_t*>(s.data()), s.size());
    }
};

// Inline implementation of conversion functions
inline Bytes String::to_bytes() const {
    return Bytes::from_string(*this);
}

inline String String::from_bytes(const Bytes& bytes) {
    return bytes.to_string();
}

} // namespace aurora

#endif // AURORA_STRING_HPP

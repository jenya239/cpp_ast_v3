#ifndef AURORA_STRING_HPP
#define AURORA_STRING_HPP

#include <string>
#include <vector>
#include <cstdint>
#include <stdexcept>
#include <sstream>
#include <utility>

namespace mlc {

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

inline String to_string(int value) {
    return String(std::to_string(value));
}

inline String to_string(long value) {
    return String(std::to_string(value));
}

inline String to_string(long long value) {
    return String(std::to_string(value));
}

inline String to_string(unsigned value) {
    return String(std::to_string(value));
}

inline String to_string(unsigned long value) {
    return String(std::to_string(value));
}

inline String to_string(unsigned long long value) {
    return String(std::to_string(value));
}

inline String to_string(float value) {
    std::ostringstream oss;
    oss << value;
    return String(oss.str());
}

inline String to_string(double value) {
    std::ostringstream oss;
    oss << value;
    return String(oss.str());
}

inline String to_string(long double value) {
    std::ostringstream oss;
    oss << value;
    return String(oss.str());
}

inline String to_string(bool value) {
    return String(value ? "true" : "false");
}

inline String to_string(const String& value) {
    return value;
}

inline String to_string(const char* value) {
    return String(value);
}

inline String to_string(const std::string& value) {
    return String(value);
}

// Parsing functions - convert strings to numbers
inline int32_t parse_i32(const String& str) {
    try {
        return std::stoi(str.as_std_string());
    } catch (...) {
        return 0; // Return 0 on parse failure (Aurora could improve this with Option<T>)
    }
}

inline float parse_f32(const String& str) {
    try {
        return std::stof(str.as_std_string());
    } catch (...) {
        return 0.0f; // Return 0.0 on parse failure
    }
}

inline bool parse_bool(const String& str) {
    const std::string& s = str.trim().lower().as_std_string();
    return s == "true" || s == "1" || s == "yes";
}

// Named wrappers for to_string (Aurora doesn't support overloading)
inline String to_string_i32(int32_t value) {
    return to_string(value);
}

inline String to_string_f32(float value) {
    return to_string(value);
}

inline String to_string_bool(bool value) {
    return to_string(value);
}

inline String format(const String& fmt, const std::vector<String>& parts) {
    const std::string& pattern = fmt.as_std_string();
    std::string result;
    result.reserve(pattern.size() + parts.size() * 8);

    size_t arg_index = 0;
    for (size_t i = 0; i < pattern.size(); ++i) {
        char ch = pattern[i];
        if (ch == '{') {
            if (i + 1 < pattern.size() && pattern[i + 1] == '{') {
                result.push_back('{');
                ++i;
            } else {
                if (arg_index < parts.size()) {
                    result += parts[arg_index++].as_std_string();
                    if (i + 1 < pattern.size() && pattern[i + 1] == '}') {
                        ++i;
                    }
                }
            }
        } else if (ch == '}' && i + 1 < pattern.size() && pattern[i + 1] == '}') {
            result.push_back('}');
            ++i;
        } else {
            result.push_back(ch);
        }
    }

    return String(result);
}

template <typename... Args>
inline String format(const String& fmt, Args&&... args) {
    std::vector<String> parts;
    parts.reserve(sizeof...(Args));
    (parts.push_back(to_string(std::forward<Args>(args))), ...);
    return format(fmt, parts);
}

} // namespace mlc

#endif // AURORA_STRING_HPP

#include "mlc_string.hpp"
#include <algorithm>
#include <cctype>
#include <sstream>

namespace mlc {

// UTF-8 helper: count characters in a UTF-8 string
size_t String::utf8_length(const std::string& str) {
    size_t count = 0;
    for (size_t i = 0; i < str.size(); ) {
        uint8_t byte = static_cast<uint8_t>(str[i]);

        // Determine how many bytes this character uses
        if ((byte & 0x80) == 0x00) {
            // 1-byte character (0xxxxxxx)
            i += 1;
        } else if ((byte & 0xE0) == 0xC0) {
            // 2-byte character (110xxxxx)
            i += 2;
        } else if ((byte & 0xF0) == 0xE0) {
            // 3-byte character (1110xxxx)
            i += 3;
        } else if ((byte & 0xF8) == 0xF0) {
            // 4-byte character (11110xxx)
            i += 4;
        } else {
            // Invalid UTF-8, skip this byte
            i += 1;
        }
        count++;
    }
    return count;
}

// UTF-8 helper: get byte index of nth character
size_t String::utf8_char_index(const std::string& str, size_t char_pos) {
    size_t current_char = 0;
    size_t byte_index = 0;

    while (byte_index < str.size() && current_char < char_pos) {
        uint8_t byte = static_cast<uint8_t>(str[byte_index]);

        if ((byte & 0x80) == 0x00) {
            byte_index += 1;
        } else if ((byte & 0xE0) == 0xC0) {
            byte_index += 2;
        } else if ((byte & 0xF0) == 0xE0) {
            byte_index += 3;
        } else if ((byte & 0xF8) == 0xF0) {
            byte_index += 4;
        } else {
            byte_index += 1;
        }
        current_char++;
    }

    return byte_index;
}

// UTF-8 helper: get one character at position
std::string String::utf8_char_at(const std::string& str, size_t char_pos) {
    size_t byte_index = utf8_char_index(str, char_pos);

    if (byte_index >= str.size()) {
        throw std::out_of_range("String character index out of range");
    }

    uint8_t byte = static_cast<uint8_t>(str[byte_index]);
    size_t char_bytes = 1;

    if ((byte & 0x80) == 0x00) {
        char_bytes = 1;
    } else if ((byte & 0xE0) == 0xC0) {
        char_bytes = 2;
    } else if ((byte & 0xF0) == 0xE0) {
        char_bytes = 3;
    } else if ((byte & 0xF8) == 0xF0) {
        char_bytes = 4;
    }

    return str.substr(byte_index, char_bytes);
}

// Substring by character positions
String String::substring(size_t start) const {
    size_t byte_start = utf8_char_index(data_, start);
    return String(data_.substr(byte_start));
}

String String::substring(size_t start, size_t length) const {
    size_t byte_start = utf8_char_index(data_, start);
    size_t byte_end = utf8_char_index(data_, start + length);
    return String(data_.substr(byte_start, byte_end - byte_start));
}

// Case conversion (simple ASCII version for MVP)
// TODO: Add ICU/Boost.Locale for proper Unicode case conversion
String String::upper() const {
    std::string result = data_;
    std::transform(result.begin(), result.end(), result.begin(),
                   [](unsigned char c) { return std::toupper(c); });
    return String(result);
}

String String::lower() const {
    std::string result = data_;
    std::transform(result.begin(), result.end(), result.begin(),
                   [](unsigned char c) { return std::tolower(c); });
    return String(result);
}

// Trimming whitespace
String String::trim() const {
    if (data_.empty()) return String();

    size_t start = 0;
    size_t end = data_.size() - 1;

    // Find first non-whitespace
    while (start < data_.size() && std::isspace(static_cast<unsigned char>(data_[start]))) {
        start++;
    }

    // Find last non-whitespace
    while (end > start && std::isspace(static_cast<unsigned char>(data_[end]))) {
        end--;
    }

    if (start > end) return String();
    return String(data_.substr(start, end - start + 1));
}

String String::trim_start() const {
    if (data_.empty()) return String();

    size_t start = 0;
    while (start < data_.size() && std::isspace(static_cast<unsigned char>(data_[start]))) {
        start++;
    }

    return String(data_.substr(start));
}

String String::trim_end() const {
    if (data_.empty()) return String();

    size_t end = data_.size() - 1;
    while (end > 0 && std::isspace(static_cast<unsigned char>(data_[end]))) {
        end--;
    }

    return String(data_.substr(0, end + 1));
}

// Splitting
std::vector<String> String::split(const String& delimiter) const {
    std::vector<String> result;

    if (delimiter.data_.empty()) {
        // Split into individual characters
        size_t char_count = length();
        for (size_t i = 0; i < char_count; i++) {
            result.push_back(String(char_at(i)));
        }
        return result;
    }

    size_t start = 0;
    size_t pos = data_.find(delimiter.data_);

    while (pos != std::string::npos) {
        result.push_back(String(data_.substr(start, pos - start)));
        start = pos + delimiter.data_.size();
        pos = data_.find(delimiter.data_, start);
    }

    // Add the last part
    result.push_back(String(data_.substr(start)));

    return result;
}

} // namespace mlc

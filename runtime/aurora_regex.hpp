#ifndef AURORA_REGEX_HPP
#define AURORA_REGEX_HPP

#include "aurora_string.hpp"
#include <regex>
#include <optional>
#include <vector>

namespace aurora {

// Forward declaration
class Match;
class Regex;

// Represents a single capture group in a match
class Capture {
private:
    String text_;
    size_t start_;
    size_t end_;

public:
    Capture(const String& text, size_t start, size_t end)
        : text_(text), start_(start), end_(end) {}

    const String& text() const { return text_; }
    size_t start() const { return start_; }
    size_t end() const { return end_; }
    size_t length() const { return text_.length(); }
};

// Represents a regex match with capture groups
class Match {
private:
    String full_match_;
    std::vector<Capture> captures_;
    size_t start_;
    size_t end_;

public:
    Match(const String& full, size_t start, size_t end)
        : full_match_(full), start_(start), end_(end) {}

    // Get the full matched text
    const String& text() const { return full_match_; }

    // Match position
    size_t start() const { return start_; }
    size_t end() const { return end_; }

    // Number of capture groups (excluding full match)
    size_t capture_count() const { return captures_.size(); }

    // Get capture group by index (0 = full match)
    const Capture& get(size_t index) const {
        if (index == 0) {
            static Capture full_capture(full_match_, start_, end_);
            return full_capture;
        }
        if (index - 1 >= captures_.size()) {
            throw std::out_of_range("Capture group index out of range");
        }
        return captures_[index - 1];
    }

    // Add a capture group (internal use)
    void add_capture(const Capture& cap) {
        captures_.push_back(cap);
    }
};

// Main Regex class
class Regex {
private:
    std::regex regex_;
    String pattern_;
    bool valid_;

public:
    // Constructors
    Regex() : valid_(false) {}

    Regex(const String& pattern) : pattern_(pattern), valid_(true) {
        try {
            regex_ = std::regex(pattern.as_std_string(),
                               std::regex_constants::ECMAScript);
        } catch (const std::regex_error& e) {
            valid_ = false;
            // In production, we'd store error message
        }
    }

    Regex(const String& pattern, std::regex_constants::syntax_option_type flags)
        : pattern_(pattern), valid_(true) {
        try {
            regex_ = std::regex(pattern.as_std_string(), flags);
        } catch (const std::regex_error& e) {
            valid_ = false;
        }
    }

    // Copy/Move
    Regex(const Regex&) = default;
    Regex(Regex&&) = default;
    Regex& operator=(const Regex&) = default;
    Regex& operator=(Regex&&) = default;

    // Check if regex is valid
    bool is_valid() const { return valid_; }
    const String& pattern() const { return pattern_; }

    // Test if string matches the pattern
    bool test(const String& text) const {
        if (!valid_) return false;
        return std::regex_search(text.as_std_string(), regex_);
    }

    // Find first match
    std::optional<Match> match(const String& text) const {
        if (!valid_) return std::nullopt;

        std::smatch sm;
        if (std::regex_search(text.as_std_string(), sm, regex_)) {
            Match m(String(sm[0].str()), sm.position(0), sm.position(0) + sm[0].length());

            // Add capture groups (excluding full match at index 0)
            for (size_t i = 1; i < sm.size(); i++) {
                if (sm[i].matched) {
                    m.add_capture(Capture(
                        String(sm[i].str()),
                        sm.position(i),
                        sm.position(i) + sm[i].length()
                    ));
                }
            }

            return m;
        }

        return std::nullopt;
    }

    // Find all matches
    std::vector<Match> match_all(const String& text) const {
        std::vector<Match> matches;
        if (!valid_) return matches;

        const std::string& str = text.as_std_string();
        std::smatch sm;
        std::string::const_iterator search_start(str.cbegin());

        while (std::regex_search(search_start, str.cend(), sm, regex_)) {
            size_t offset = search_start - str.cbegin();
            Match m(String(sm[0].str()),
                   offset + sm.position(0),
                   offset + sm.position(0) + sm[0].length());

            // Add capture groups
            for (size_t i = 1; i < sm.size(); i++) {
                if (sm[i].matched) {
                    m.add_capture(Capture(
                        String(sm[i].str()),
                        offset + sm.position(i),
                        offset + sm.position(i) + sm[i].length()
                    ));
                }
            }

            matches.push_back(m);
            search_start = sm.suffix().first;
        }

        return matches;
    }

    // Replace first match
    String replace(const String& text, const String& replacement) const {
        if (!valid_) return text;

        std::string result = std::regex_replace(
            text.as_std_string(),
            regex_,
            replacement.as_std_string(),
            std::regex_constants::format_first_only
        );

        return String(result);
    }

    // Replace all matches
    String replace_all(const String& text, const String& replacement) const {
        if (!valid_) return text;

        std::string result = std::regex_replace(
            text.as_std_string(),
            regex_,
            replacement.as_std_string()
        );

        return String(result);
    }

    // Split string by regex
    std::vector<String> split(const String& text) const {
        std::vector<String> result;
        if (!valid_) {
            result.push_back(text);
            return result;
        }

        const std::string& str = text.as_std_string();
        std::sregex_token_iterator iter(str.begin(), str.end(), regex_, -1);
        std::sregex_token_iterator end;

        for (; iter != end; ++iter) {
            result.push_back(String(*iter));
        }

        return result;
    }

    // Comparison
    bool operator==(const Regex& other) const {
        return pattern_ == other.pattern_;
    }

    bool operator!=(const Regex& other) const {
        return pattern_ != other.pattern_;
    }
};

// Helper function to create regex (can be used for Aurora's regex() syntax)
inline Regex regex(const String& pattern) {
    return Regex(pattern);
}

// Case-insensitive regex
inline Regex regex_i(const String& pattern) {
    return Regex(pattern, std::regex_constants::ECMAScript | std::regex_constants::icase);
}

} // namespace aurora

#endif // AURORA_REGEX_HPP

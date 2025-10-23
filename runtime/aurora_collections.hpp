#ifndef AURORA_COLLECTIONS_HPP
#define AURORA_COLLECTIONS_HPP

#include <vector>
#include <type_traits>
#include <utility>
#include "aurora_string.hpp"

namespace aurora::collections {

template <typename T, typename Func>
auto map(const std::vector<T>& items, Func&& func) {
    using Result = std::decay_t<std::invoke_result_t<Func, const T&>>;
    std::vector<Result> result;
    result.reserve(items.size());
    for (const auto& item : items) {
        result.push_back(func(item));
    }
    return result;
}

template <typename T, typename Func>
auto filter(const std::vector<T>& items, Func&& predicate) {
    std::vector<T> result;
    for (const auto& item : items) {
        if (predicate(item)) {
            result.push_back(item);
        }
    }
    return result;
}

template <typename T, typename Acc, typename Func>
Acc fold(const std::vector<T>& items, Acc acc, Func&& reducer) {
    for (const auto& item : items) {
        acc = reducer(acc, item);
    }
    return acc;
}

template <typename T>
bool is_empty(const std::vector<T>& items) {
    return items.empty();
}

template <typename T>
aurora::String join(const std::vector<T>& items, const aurora::String& separator) {
    if (items.empty()) {
        return aurora::String("");
    }

    aurora::String result = aurora::to_string(items.front());
    for (size_t i = 1; i < items.size(); ++i) {
        result += separator;
        result += aurora::to_string(items[i]);
    }
    return result;
}

// Specialized version for string arrays
inline aurora::String join_strings(const std::vector<aurora::String>& items, const aurora::String& separator) {
    return join(items, separator);
}

// Reverse array (generic)
template <typename T>
std::vector<T> reverse(const std::vector<T>& items) {
    std::vector<T> result(items.rbegin(), items.rend());
    return result;
}

// Specialized reverse functions
inline std::vector<int32_t> reverse_i32(const std::vector<int32_t>& items) {
    return reverse(items);
}

inline std::vector<float> reverse_f32(const std::vector<float>& items) {
    return reverse(items);
}

inline std::vector<aurora::String> reverse_str(const std::vector<aurora::String>& items) {
    return reverse(items);
}

// Take first n elements (generic)
template <typename T>
std::vector<T> take(const std::vector<T>& items, int32_t n) {
    if (n <= 0) return std::vector<T>{};
    size_t count = std::min(static_cast<size_t>(n), items.size());
    return std::vector<T>(items.begin(), items.begin() + count);
}

// Specialized take functions
inline std::vector<int32_t> take_i32(const std::vector<int32_t>& items, int32_t n) {
    return take(items, n);
}

inline std::vector<float> take_f32(const std::vector<float>& items, int32_t n) {
    return take(items, n);
}

inline std::vector<aurora::String> take_str(const std::vector<aurora::String>& items, int32_t n) {
    return take(items, n);
}

// Drop first n elements (generic)
template <typename T>
std::vector<T> drop(const std::vector<T>& items, int32_t n) {
    if (n <= 0) return items;
    size_t skip = std::min(static_cast<size_t>(n), items.size());
    return std::vector<T>(items.begin() + skip, items.end());
}

// Specialized drop functions
inline std::vector<int32_t> drop_i32(const std::vector<int32_t>& items, int32_t n) {
    return drop(items, n);
}

inline std::vector<float> drop_f32(const std::vector<float>& items, int32_t n) {
    return drop(items, n);
}

inline std::vector<aurora::String> drop_str(const std::vector<aurora::String>& items, int32_t n) {
    return drop(items, n);
}

// Slice array [start, end) (generic)
template <typename T>
std::vector<T> slice(const std::vector<T>& items, int32_t start, int32_t end) {
    if (start < 0) start = 0;
    if (end > static_cast<int32_t>(items.size())) end = items.size();
    if (start >= end) return std::vector<T>{};
    return std::vector<T>(items.begin() + start, items.begin() + end);
}

// Specialized slice functions
inline std::vector<int32_t> slice_i32(const std::vector<int32_t>& items, int32_t start, int32_t end) {
    return slice(items, start, end);
}

inline std::vector<float> slice_f32(const std::vector<float>& items, int32_t start, int32_t end) {
    return slice(items, start, end);
}

inline std::vector<aurora::String> slice_str(const std::vector<aurora::String>& items, int32_t start, int32_t end) {
    return slice(items, start, end);
}

// Check if array contains element (generic)
template <typename T>
bool contains(const std::vector<T>& items, const T& element) {
    for (const auto& item : items) {
        if (item == element) return true;
    }
    return false;
}

// Specialized contains functions
inline bool contains_i32(const std::vector<int32_t>& items, int32_t element) {
    return contains(items, element);
}

inline bool contains_f32(const std::vector<float>& items, float element) {
    return contains(items, element);
}

inline bool contains_str(const std::vector<aurora::String>& items, const aurora::String& element) {
    return contains(items, element);
}

// Sum for integers
inline int32_t sum_i32(const std::vector<int32_t>& items) {
    int32_t result = 0;
    for (auto item : items) {
        result += item;
    }
    return result;
}

// Sum for floats
inline float sum_f32(const std::vector<float>& items) {
    float result = 0.0f;
    for (auto item : items) {
        result += item;
    }
    return result;
}

// Min for integers
inline int32_t min_i32(const std::vector<int32_t>& items) {
    if (items.empty()) return 0;
    int32_t result = items[0];
    for (auto item : items) {
        if (item < result) result = item;
    }
    return result;
}

// Max for integers
inline int32_t max_i32(const std::vector<int32_t>& items) {
    if (items.empty()) return 0;
    int32_t result = items[0];
    for (auto item : items) {
        if (item > result) result = item;
    }
    return result;
}

// Min for floats
inline float min_f32(const std::vector<float>& items) {
    if (items.empty()) return 0.0f;
    float result = items[0];
    for (auto item : items) {
        if (item < result) result = item;
    }
    return result;
}

// Max for floats
inline float max_f32(const std::vector<float>& items) {
    if (items.empty()) return 0.0f;
    float result = items[0];
    for (auto item : items) {
        if (item > result) result = item;
    }
    return result;
}

// Generate range [start, end)
inline std::vector<int32_t> range(int32_t start, int32_t end) {
    std::vector<int32_t> result;
    if (start < end) {
        result.reserve(end - start);
        for (int32_t i = start; i < end; ++i) {
            result.push_back(i);
        }
    }
    return result;
}

} // namespace aurora::collections

#endif // AURORA_COLLECTIONS_HPP

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

} // namespace aurora::collections

#endif // AURORA_COLLECTIONS_HPP

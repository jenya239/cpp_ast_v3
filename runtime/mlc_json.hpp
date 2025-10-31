#ifndef AURORA_JSON_HPP
#define AURORA_JSON_HPP

#include <variant>
#include <vector>
#include <string>
#include <optional>
#include "json.hpp"
#include "mlc_string.hpp"

namespace mlc::json {

using json = nlohmann::json;

// Forward declaration for JsonValue
struct JsonValue;

// JsonValue type that mirrors Aurora's JsonValue sum type
struct JsonValue {
    // Variant holding different JSON types
    std::variant<
        std::monostate,              // JsonNull
        bool,                        // JsonBool
        double,                      // JsonNumber (using double for better precision)
        mlc::String,              // JsonString
        std::vector<JsonValue>,      // JsonArray
        json                         // JsonObject (using nlohmann::json for objects)
    > value;

    // Constructors
    JsonValue() : value(std::monostate{}) {}
    JsonValue(std::monostate) : value(std::monostate{}) {}
    JsonValue(bool b) : value(b) {}
    JsonValue(double n) : value(n) {}
    JsonValue(float n) : value(static_cast<double>(n)) {}
    JsonValue(int32_t n) : value(static_cast<double>(n)) {}
    JsonValue(const mlc::String& s) : value(s) {}
    JsonValue(const std::vector<JsonValue>& arr) : value(arr) {}
    JsonValue(const json& obj) : value(obj) {}

    // Type checking
    bool is_null() const { return std::holds_alternative<std::monostate>(value); }
    bool is_bool() const { return std::holds_alternative<bool>(value); }
    bool is_number() const { return std::holds_alternative<double>(value); }
    bool is_string() const { return std::holds_alternative<mlc::String>(value); }
    bool is_array() const { return std::holds_alternative<std::vector<JsonValue>>(value); }
    bool is_object() const { return std::holds_alternative<json>(value); }

    // Value getters (return std::optional for safety)
    std::optional<bool> as_bool() const {
        if (auto* b = std::get_if<bool>(&value)) return *b;
        return std::nullopt;
    }

    std::optional<double> as_number() const {
        if (auto* n = std::get_if<double>(&value)) return *n;
        return std::nullopt;
    }

    std::optional<mlc::String> as_string() const {
        if (auto* s = std::get_if<mlc::String>(&value)) return *s;
        return std::nullopt;
    }

    std::optional<std::vector<JsonValue>> as_array() const {
        if (auto* arr = std::get_if<std::vector<JsonValue>>(&value)) return *arr;
        return std::nullopt;
    }

    std::optional<json> as_object() const {
        if (auto* obj = std::get_if<json>(&value)) return *obj;
        return std::nullopt;
    }
};

// Convert nlohmann::json to Aurora JsonValue
inline JsonValue from_nlohmann_json(const json& j) {
    if (j.is_null()) {
        return JsonValue(std::monostate{});
    } else if (j.is_boolean()) {
        return JsonValue(j.get<bool>());
    } else if (j.is_number()) {
        return JsonValue(j.get<double>());
    } else if (j.is_string()) {
        return JsonValue(mlc::String(j.get<std::string>().c_str()));
    } else if (j.is_array()) {
        std::vector<JsonValue> arr;
        arr.reserve(j.size());
        for (const auto& elem : j) {
            arr.push_back(from_nlohmann_json(elem));
        }
        return JsonValue(arr);
    } else if (j.is_object()) {
        return JsonValue(j);  // Store object as nlohmann::json directly
    }
    return JsonValue(std::monostate{});
}

// Convert Aurora JsonValue to nlohmann::json
inline json to_nlohmann_json(const JsonValue& jv) {
    if (jv.is_null()) {
        return json(nullptr);
    } else if (jv.is_bool()) {
        return json(*jv.as_bool());
    } else if (jv.is_number()) {
        return json(*jv.as_number());
    } else if (jv.is_string()) {
        return json(jv.as_string()->c_str());
    } else if (jv.is_array()) {
        json arr = json::array();
        for (const auto& elem : *jv.as_array()) {
            arr.push_back(to_nlohmann_json(elem));
        }
        return arr;
    } else if (jv.is_object()) {
        return *jv.as_object();
    }
    return json(nullptr);
}

// Parse JSON string - returns JsonValue or JsonNull on error
// TODO: Return Result<JsonValue, String> when Result type is available
inline JsonValue parse_json(const mlc::String& json_str) {
    try {
        json parsed = json::parse(json_str.c_str());
        return from_nlohmann_json(parsed);
    } catch (const json::parse_error& e) {
        // Return null on parse error for now
        return JsonValue(std::monostate{});
    } catch (const std::exception& e) {
        return JsonValue(std::monostate{});
    }
}

// Stringify JSON value to string
inline mlc::String stringify_json(const JsonValue& value) {
    json j = to_nlohmann_json(value);
    return mlc::String(j.dump().c_str());
}

// Stringify JSON value with pretty printing
inline mlc::String stringify_json_pretty(const JsonValue& value, int32_t indent) {
    json j = to_nlohmann_json(value);
    return mlc::String(j.dump(indent).c_str());
}

// Helper constructors
inline JsonValue json_null() {
    return JsonValue(std::monostate{});
}

inline JsonValue json_bool(bool b) {
    return JsonValue(b);
}

inline JsonValue json_number(float n) {
    return JsonValue(n);
}

inline JsonValue json_string(const mlc::String& s) {
    return JsonValue(s);
}

inline JsonValue json_array(const std::vector<JsonValue>& arr) {
    return JsonValue(arr);
}

// Object construction helper - creates empty object
inline JsonValue json_object() {
    return JsonValue(json::object());
}

// Get value from JSON object by key
inline std::optional<JsonValue> json_get(const JsonValue& obj, const mlc::String& key) {
    if (auto* j = std::get_if<json>(&obj.value)) {
        if (j->is_object() && j->contains(key.c_str())) {
            return from_nlohmann_json((*j)[key.c_str()]);
        }
    }
    return std::nullopt;
}

// Set value in JSON object
inline JsonValue json_set(JsonValue obj, const mlc::String& key, const JsonValue& value) {
    if (auto* j = std::get_if<json>(&obj.value)) {
        if (j->is_object()) {
            json new_obj = *j;
            new_obj[key.c_str()] = to_nlohmann_json(value);
            return JsonValue(new_obj);
        }
    }
    // If not an object, create a new object with this key-value pair
    json new_obj = json::object();
    new_obj[key.c_str()] = to_nlohmann_json(value);
    return JsonValue(new_obj);
}

// Check if object has key
inline bool json_has_key(const JsonValue& obj, const mlc::String& key) {
    if (auto* j = std::get_if<json>(&obj.value)) {
        if (j->is_object()) {
            return j->contains(key.c_str());
        }
    }
    return false;
}

// Get all keys from JSON object
inline std::vector<mlc::String> json_keys(const JsonValue& obj) {
    std::vector<mlc::String> keys;
    if (auto* j = std::get_if<json>(&obj.value)) {
        if (j->is_object()) {
            for (auto it = j->begin(); it != j->end(); ++it) {
                keys.push_back(mlc::String(it.key().c_str()));
            }
        }
    }
    return keys;
}

// Get array length
inline int32_t json_array_length(const JsonValue& arr) {
    if (auto* vec = std::get_if<std::vector<JsonValue>>(&arr.value)) {
        return static_cast<int32_t>(vec->size());
    }
    return 0;
}

// Get element from JSON array by index
inline std::optional<JsonValue> json_array_get(const JsonValue& arr, int32_t index) {
    if (auto* vec = std::get_if<std::vector<JsonValue>>(&arr.value)) {
        if (index >= 0 && index < static_cast<int32_t>(vec->size())) {
            return (*vec)[index];
        }
    }
    return std::nullopt;
}

// Push element to JSON array
inline JsonValue json_array_push(const JsonValue& arr, const JsonValue& value) {
    std::vector<JsonValue> new_arr;

    if (auto* vec = std::get_if<std::vector<JsonValue>>(&arr.value)) {
        new_arr = *vec;
    }

    new_arr.push_back(value);
    return JsonValue(new_arr);
}

} // namespace mlc::json

#endif // AURORA_JSON_HPP

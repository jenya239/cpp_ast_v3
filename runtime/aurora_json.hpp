#ifndef AURORA_JSON_HPP
#define AURORA_JSON_HPP

#include <variant>
#include <vector>
#include <string>
#include <optional>
#include "json.hpp"
#include "aurora_string.hpp"

namespace aurora::json {

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
        aurora::String,              // JsonString
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
    JsonValue(const aurora::String& s) : value(s) {}
    JsonValue(const std::vector<JsonValue>& arr) : value(arr) {}
    JsonValue(const json& obj) : value(obj) {}

    // Type checking
    bool is_null() const { return std::holds_alternative<std::monostate>(value); }
    bool is_bool() const { return std::holds_alternative<bool>(value); }
    bool is_number() const { return std::holds_alternative<double>(value); }
    bool is_string() const { return std::holds_alternative<aurora::String>(value); }
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

    std::optional<aurora::String> as_string() const {
        if (auto* s = std::get_if<aurora::String>(&value)) return *s;
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
        return JsonValue(aurora::String(j.get<std::string>().c_str()));
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

// Parse JSON string - returns JsonValue on success, error string on failure
// For now, we'll use std::variant to represent Result<JsonValue, String>
inline std::variant<JsonValue, aurora::String> parse_json(const aurora::String& json_str) {
    try {
        json parsed = json::parse(json_str.c_str());
        return from_nlohmann_json(parsed);
    } catch (const json::parse_error& e) {
        return aurora::String(e.what());
    } catch (const std::exception& e) {
        return aurora::String(e.what());
    }
}

// Stringify JSON value to string
inline aurora::String stringify_json(const JsonValue& value) {
    json j = to_nlohmann_json(value);
    return aurora::String(j.dump().c_str());
}

// Stringify JSON value with pretty printing
inline aurora::String stringify_json_pretty(const JsonValue& value, int32_t indent) {
    json j = to_nlohmann_json(value);
    return aurora::String(j.dump(indent).c_str());
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

inline JsonValue json_string(const aurora::String& s) {
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
inline std::optional<JsonValue> json_get(const JsonValue& obj, const aurora::String& key) {
    if (auto* j = std::get_if<json>(&obj.value)) {
        if (j->is_object() && j->contains(key.c_str())) {
            return from_nlohmann_json((*j)[key.c_str()]);
        }
    }
    return std::nullopt;
}

// Set value in JSON object
inline JsonValue json_set(JsonValue obj, const aurora::String& key, const JsonValue& value) {
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

} // namespace aurora::json

#endif // AURORA_JSON_HPP

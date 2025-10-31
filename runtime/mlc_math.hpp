#ifndef AURORA_MATH_HPP
#define AURORA_MATH_HPP

#include <cmath>
#include <cstdint>
#include <algorithm>

namespace mlc::math {

// Basic arithmetic functions
inline int32_t abs(int32_t x) {
    return std::abs(x);
}

inline float abs_f(float x) {
    return std::fabs(x);
}

inline int32_t min(int32_t a, int32_t b) {
    return std::min(a, b);
}

inline int32_t max(int32_t a, int32_t b) {
    return std::max(a, b);
}

inline float min_f(float a, float b) {
    return std::fmin(a, b);
}

inline float max_f(float a, float b) {
    return std::fmax(a, b);
}

// Power and root functions
inline float pow_f(float base, float exp) {
    return std::pow(base, exp);
}

inline float sqrt_f(float x) {
    return std::sqrt(x);
}

// Trigonometric functions
inline float sin_f(float x) {
    return std::sin(x);
}

inline float cos_f(float x) {
    return std::cos(x);
}

inline float tan_f(float x) {
    return std::tan(x);
}

// Mathematical constants
constexpr float PI = 3.14159265359f;
constexpr float E = 2.71828182846f;

} // namespace mlc::math

#endif // AURORA_MATH_HPP

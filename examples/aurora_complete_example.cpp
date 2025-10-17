// Complete Aurora Pattern Matching Example - Generated C++
// This file shows what Aurora compiles to with all necessary helpers

#include <variant>
#include <iostream>

// Overloaded helper for std::visit (C++17 pattern)
template<class... Ts> struct overloaded : Ts... { using Ts::operator()...; };
template<class... Ts> overloaded(Ts...) -> overloaded<Ts...>;

// Generated from Aurora code:
// type Shape = Circle(f32) | Rect(f32, f32) | Point
struct Circle {float field0;};
struct Rect {float field0; float field1;};
struct Point {};
using Shape = std::variant<Circle, Rect, Point>;

// Generated from Aurora code:
// fn area(s: Shape) -> f32 =
//   match s
//     | Circle(r) => 3.14 * r * r
//     | Rect(w, h) => w * h
//     | Point => 0.0
float area(Shape s) {
  return std::visit(overloaded{
    [&](const Circle& circle) {
      auto [r] = circle;
      return 3.14f * r * r;
    },
    [&](const Rect& rect) {
      auto [w, h] = rect;
      return w * h;
    },
    [&](const Point& point) {
      return 0.0f;
    }
  }, s);
}

// Example usage
int main() {
  Shape circle = Circle{5.0f};
  Shape rect = Rect{4.0f, 3.0f};
  Shape point = Point{};

  std::cout << "Circle area: " << area(circle) << std::endl;  // 78.5
  std::cout << "Rect area: " << area(rect) << std::endl;      // 12.0
  std::cout << "Point area: " << area(point) << std::endl;    // 0.0

  return 0;
}

#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "../lib/aurora"

puts "=" * 80
puts "  AURORA LANGUAGE - Module System Demonstration"
puts "=" * 80
puts
puts "Generating traditional C++ header (.hpp) and implementation (.cpp) files"
puts "NOT using C++20 modules - using classic #include with header guards"
puts
puts "=" * 80
puts

# Example 1: Simple module with function
puts "Example 1: Simple Module"
puts "-" * 80

aurora_source_1 = <<~AURORA
  module Math

  fn add(a: i32, b: i32) -> i32 = a + b
  fn multiply(a: i32, b: i32) -> i32 = a * b
AURORA

puts "Aurora Source:"
puts aurora_source_1
puts

result = Aurora.to_hpp_cpp(aurora_source_1)

puts "Generated math.hpp:"
puts "-" * 40
puts result[:header]
puts

puts "Generated math.cpp:"
puts "-" * 40
puts result[:implementation]
puts
puts "=" * 80
puts

# Example 2: Module with imports
puts "Example 2: Module with Imports"
puts "-" * 80

aurora_source_2 = <<~AURORA
  module Geometry

  import Math

  type Point = { x: f32, y: f32 }

  fn distance(p1: Point, p2: Point) -> f32 =
    Math::sqrt((p2.x - p1.x) * (p2.x - p1.x) + (p2.y - p1.y) * (p2.y - p1.y))
AURORA

puts "Aurora Source:"
puts aurora_source_2
puts

result = Aurora.to_hpp_cpp(aurora_source_2)

puts "Generated geometry.hpp:"
puts "-" * 40
puts result[:header]
puts

puts "Generated geometry.cpp:"
puts "-" * 40
puts result[:implementation]
puts
puts "=" * 80
puts

# Example 3: Nested module path
puts "Example 3: Nested Module Path"
puts "-" * 80

aurora_source_3 = <<~AURORA
  module Math::Vector

  type Vec3 = { x: f32, y: f32, z: f32 }

  fn dot<T>(a: Vec3, b: Vec3) -> f32 =
    a.x * b.x + a.y * b.y + a.z * b.z
AURORA

puts "Aurora Source:"
puts aurora_source_3
puts

result = Aurora.to_hpp_cpp(aurora_source_3)

puts "Generated math/vector.hpp:"
puts "-" * 40
puts result[:header]
puts

puts "Generated math/vector.cpp:"
puts "-" * 40
puts result[:implementation]
puts
puts "=" * 80
puts

# Example 4: Module with sum types
puts "Example 4: Module with Sum Types"
puts "-" * 80

aurora_source_4 = <<~AURORA
  module Shapes

  type Shape = Circle(f32) | Rect(f32, f32)

  fn area(s: Shape) -> f32 =
    match s
      | Circle(r) => r * r
      | Rect(w, h) => w * h
AURORA

puts "Aurora Source:"
puts aurora_source_4
puts

result = Aurora.to_hpp_cpp(aurora_source_4)

puts "Generated shapes.hpp:"
puts "-" * 40
puts result[:header]
puts

puts "Generated shapes.cpp:"
puts "-" * 40
puts result[:implementation]
puts
puts "=" * 80
puts "  MODULE SYSTEM FEATURES"
puts "=" * 80
puts
puts "✅ Implemented Features:"
puts "  • Module declarations: module Math, module Math::Vector"
puts "  • Import statements: import Math, import Math::Vector"
puts "  • Selective imports: import Math::{add, subtract}"
puts "  • Header generation with include guards"
puts "  • Namespace mapping: Math::Vector → namespace math::vector"
puts "  • Include path mapping: Math::Vector → #include \"math/vector.hpp\""
puts "  • Function declarations in .hpp, implementations in .cpp"
puts "  • Type definitions in .hpp"
puts "  • Proper separation of interface and implementation"
puts
puts "📁 File Structure:"
puts "  module Math           → math.hpp + math.cpp"
puts "  module Math::Vector   → math/vector.hpp + math/vector.cpp"
puts "  module App::Core::DB  → app/core/db.hpp + app/core/db.cpp"
puts
puts "🔗 C++ Generation:"
puts "  • Header guards: #ifndef MATH_VECTOR_HPP"
puts "  • Namespaces: namespace math::vector { ... }"
puts "  • Includes: #include <variant>, #include <string>"
puts "  • Forward declarations and prototypes in headers"
puts "  • Full implementations in .cpp files"
puts
puts "=" * 80
puts "Module system demo completed!"
puts "=" * 80

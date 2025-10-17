#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "../lib/aurora"

puts "=" * 80
puts "  AURORA LANGUAGE - ESM-Style Module System"
puts "=" * 80
puts
puts "JavaScript/TypeScript-like module syntax with export/import"
puts "Compiles to traditional C++ .hpp/.cpp files (NOT C++20 modules)"
puts
puts "=" * 80
puts

# Example 1: Export named functions
puts "Example 1: Export Named Functions"
puts "-" * 80

aurora_source_1 = <<~AURORA
  // math.aurora
  export fn add(a: i32, b: i32) -> i32 = a + b
  export fn multiply(a: i32, b: i32) -> i32 = a * b

  fn helper() -> i32 = 42  // private function
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

# Example 2: Named imports
puts "Example 2: Named Imports (ESM-style)"
puts "-" * 80

aurora_source_2 = <<~AURORA
  import { add, multiply } from "./math"

  export fn calculate(x: i32, y: i32) -> i32 =
    add(x, y) |> multiply(2)
AURORA

puts "Aurora Source:"
puts aurora_source_2
puts

result = Aurora.to_hpp_cpp(aurora_source_2)

puts "Generated C++ header:"
puts "-" * 40
puts result[:header][0..400] + "..."
puts
puts "=" * 80
puts

# Example 3: Wildcard imports
puts "Example 3: Wildcard Imports (import * as ...)"
puts "-" * 80

aurora_source_3 = <<~AURORA
  import * as Math from "./math"

  export fn process(x: i32) -> i32 =
    Math::add(x, 10)
AURORA

puts "Aurora Source:"
puts aurora_source_3
puts

result = Aurora.to_hpp_cpp(aurora_source_3)

puts "Generated C++ header snippet:"
puts "-" * 40
puts result[:header][0..300] + "..."
puts
puts "=" * 80
puts

# Example 4: Export types
puts "Example 4: Export Types and Functions"
puts "-" * 80

aurora_source_4 = <<~AURORA
  // geometry.aurora
  export type Point = { x: f32, y: f32 }
  export type Shape = Circle(f32) | Rect(f32, f32)

  export fn area(s: Shape) -> f32 =
    match s
      | Circle(r) => r * r * 3.14159
      | Rect(w, h) => w * h

  fn internal_helper() -> i32 = 0  // private
AURORA

puts "Aurora Source:"
puts aurora_source_4
puts

result = Aurora.to_hpp_cpp(aurora_source_4)

puts "Generated geometry.hpp:"
puts "-" * 40
puts result[:header]
puts

puts "=" * 80
puts

# Example 5: Complete module example
puts "Example 5: Complete Module with Multiple Imports"
puts "-" * 80

aurora_source_5 = <<~AURORA
  import { Point } from "./geometry"
  import { sqrt } from "./math"
  import * as Utils from "../utils"

  export fn distance(p1: Point, p2: Point) -> f32 =
    sqrt((p2.x - p1.x) * (p2.x - p1.x) + (p2.y - p1.y) * (p2.y - p1.y))

  export fn midpoint(p1: Point, p2: Point) -> Point =
    { x: (p1.x + p2.x) / 2.0, y: (p1.y + p2.y) / 2.0 }
AURORA

puts "Aurora Source:"
puts aurora_source_5
puts

result = Aurora.to_hpp_cpp(aurora_source_5)

puts "Generated C++ header (excerpt):"
puts "-" * 40
puts result[:header][0..500] + "..."
puts
puts "=" * 80
puts "  ESM MODULE SYNTAX SUMMARY"
puts "=" * 80
puts
puts "✅ Exports:"
puts "  • Named exports:    export fn add(a: i32) -> i32"
puts "  •                   export type Point = { x: f32 }"
puts "  • Private by default (no export keyword)"
puts
puts "✅ Imports:"
puts "  • Named imports:    import { add, multiply } from \"./math\""
puts "  • Wildcard import:  import * as Math from \"./math\""
puts "  • Relative paths:   \"./file\", \"../parent\", \"/absolute\""
puts "  • Backward compat:  import Math  (module name)"
puts
puts "✅ File Paths:"
puts "  • Relative:         \"./math\" → #include \"./math.hpp\""
puts "  • Parent:           \"../core/utils\" → #include \"../core/utils.hpp\""
puts "  • Module name:      Math::Vector → #include \"math/vector.hpp\""
puts "  • No ambiguity - explicit file paths like ESM!"
puts
puts "✅ C++ Generation:"
puts "  • Header guards:    #ifndef MATH_HPP"
puts "  • Namespaces:       namespace math { ... }"
puts "  • Includes:         #include statements from imports"
puts "  • Declarations:     Function prototypes in .hpp"
puts "  • Implementations:  Full definitions in .cpp"
puts
puts "🎯 Familiar Syntax:"
puts "  • Like JavaScript/TypeScript ESM modules"
puts "  • Like Python import/from syntax"
puts "  • Modern and intuitive for web developers"
puts "  • Zero-cost: compiles to efficient C++"
puts
puts "=" * 80
puts "ESM module system demo completed!"
puts "=" * 80

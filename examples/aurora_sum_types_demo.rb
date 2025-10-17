#!/usr/bin/env ruby
# frozen_string_literal: true

# Aurora Language Demo - Sum Types (Algebraic Data Types)
# Demonstrates the new sum types feature in Aurora (2025-10-17)

require_relative "../lib/aurora"

puts "=" * 70
puts "  AURORA LANGUAGE DEMO - Sum Types (Variants)"
puts "=" * 70
puts

# Example 1: Simple sum type for shapes
puts "Example 1: Shape variants"
puts "-" * 70

aurora_source_1 = <<~AURORA
  type Shape = Circle(f32) | Rect(f32, f32) | Point
AURORA

puts "Aurora Source:"
puts aurora_source_1
puts

begin
  cpp_code = Aurora.to_cpp(aurora_source_1)
  puts "Generated C++:"
  puts cpp_code
  puts
  puts "✅ SUCCESS!"
rescue => e
  puts "❌ ERROR: #{e.message}"
  puts e.backtrace[0..5].join("\n")
end

puts
puts "=" * 70
puts

# Example 2: Result type (like Rust's Result<T, E>)
puts "Example 2: Result type with named fields"
puts "-" * 70

aurora_source_2 = <<~AURORA
  type Result = Ok { value: i32 } | Err { code: i32 }
AURORA

puts "Aurora Source:"
puts aurora_source_2
puts

begin
  cpp_code = Aurora.to_cpp(aurora_source_2)
  puts "Generated C++:"
  puts cpp_code
  puts
  puts "✅ SUCCESS!"
rescue => e
  puts "❌ ERROR: #{e.message}"
end

puts
puts "=" * 70
puts

# Example 3: Option type (like Rust's Option<T>)
puts "Example 3: Option type"
puts "-" * 70

aurora_source_3 = <<~AURORA
  type Option = Some(i32) | None
AURORA

puts "Aurora Source:"
puts aurora_source_3
puts

begin
  cpp_code = Aurora.to_cpp(aurora_source_3)
  puts "Generated C++:"
  puts cpp_code
  puts
  puts "✅ SUCCESS!"
rescue => e
  puts "❌ ERROR: #{e.message}"
end

puts
puts "=" * 70
puts
puts "HOW IT WORKS:"
puts "=" * 70
puts
puts "1. Aurora sum types compile to C++ std::variant"
puts "2. Each variant becomes a separate C++ struct"
puts "3. The sum type is a type alias: using Shape = std::variant<Circle, Rect, Point>;"
puts "4. Variants can have:"
puts "   - No fields: Point"
puts "   - Tuple-like fields: Circle(f32)"
puts "   - Named fields: Ok { value: i32 }"
puts
puts "NEXT STEPS:"
puts "✅ Sum types implemented"
puts "⏳ Pattern matching with match expressions (coming next)"
puts "⏳ Generic types: Result<T, E>, Option<T>"
puts "⏳ Exhaustiveness checking"
puts
puts "=" * 70
puts "Demo completed!"
puts "=" * 70

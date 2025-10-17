#!/usr/bin/env ruby
# frozen_string_literal: true

# Aurora Language Demo - Pattern Matching
# Demonstrates full pattern matching with sum types (2025-10-17)

require_relative "../lib/aurora"

puts "=" * 70
puts "  AURORA LANGUAGE DEMO - Pattern Matching"
puts "=" * 70
puts

# Example 1: Simple pattern matching on shapes
puts "Example 1: Shape area calculation"
puts "-" * 70

aurora_source_1 = <<~AURORA
  type Shape = Circle(f32) | Rect(f32, f32) | Point

  fn area(s: Shape) -> f32 =
    match s
      | Circle(r) => r
      | Rect(w, h) => w
      | Point => 0.0
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

# Example 2: Result type with pattern matching
puts "Example 2: Result type error handling"
puts "-" * 70

aurora_source_2 = <<~AURORA
  type Result = Ok(i32) | Err(i32)

  fn handle_result(r: Result) -> i32 =
    match r
      | Ok(value) => value
      | Err(code) => code
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

# Example 3: Pattern matching with wildcard
puts "Example 3: Wildcard patterns"
puts "-" * 70

aurora_source_3 = <<~AURORA
  type Option = Some(i32) | None

  fn get_or_default(opt: Option) -> i32 =
    match opt
      | Some(x) => x
      | None => 0
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
puts "Pattern Matching Compilation:"
puts "1. Aurora match expression → CoreIR MatchExpr"
puts "2. Each pattern arm → Lambda with type-based overloading"
puts "3. Generates: std::visit(overloaded{lambda1, lambda2, ...}, variant)"
puts
puts "Pattern Types:"
puts "  - Constructor: Circle(r) → [&](const Circle& circle) { auto [r] = circle; ... }"
puts "  - Wildcard: _ → [&](auto&&) { ... }"
puts "  - Literal: 42 → handled via wildcard with check"
puts
puts "C++17 Features Used:"
puts "  - std::variant for sum types"
puts "  - std::visit for pattern matching"
puts "  - Structured bindings for destructuring"
puts "  - Generic lambdas for wildcards"
puts "  - Overloaded pattern for visitor"
puts
puts "Example C++ Output Structure:"
puts "  std::visit(overloaded{"
puts "    [&](const Circle& circle) { auto [r] = circle; return expr; },"
puts "    [&](const Point&) { return expr; }"
puts "  }, shape_value)"
puts
puts "=" * 70
puts "Demo completed!"
puts "=" * 70

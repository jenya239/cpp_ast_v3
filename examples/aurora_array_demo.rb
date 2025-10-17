#!/usr/bin/env ruby
# frozen_string_literal: true

# Aurora Language Demo - Array Literals
# Demonstrates array literal support in Aurora (2025-10-17)

require_relative "../lib/aurora"

puts "=" * 70
puts "  AURORA LANGUAGE DEMO - Array Literals"
puts "=" * 70
puts

# Example 1: Simple array literal
puts "Example 1: Simple array literal"
puts "-" * 70

aurora_source_1 = <<~AURORA
  fn numbers() -> i32 =
    [1, 2, 3, 4, 5]
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

# Example 2: Array with computed values
puts "Example 2: Array with expressions"
puts "-" * 70

aurora_source_2 = <<~AURORA
  fn computed() -> i32 =
    [1, 1 + 1, 2 + 1, 3 + 1]
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

# Example 3: Array with pipe operator
puts "Example 3: Array with pipe operator"
puts "-" * 70

aurora_source_3 = <<~AURORA
  fn double(x: i32) -> i32 = x + x

  fn test() -> i32 =
    [1, 2, 3] |> double
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
puts "1. Aurora array literals compile to C++ std::vector"
puts "2. Syntax: [1, 2, 3] becomes std::vector<int>{1, 2, 3}"
puts "3. Element type is inferred from the first element"
puts "4. Arrays can contain:"
puts "   - Literal values: [1, 2, 3]"
puts "   - Expressions: [1, 1+1, 2+1]"
puts "   - Variables and function calls"
puts "5. Arrays work with pipe operator:"
puts "   [1, 2, 3] |> func becomes func(std::vector<int>{1, 2, 3})"
puts
puts "NEXT STEPS:"
puts "✅ Array literals implemented"
puts "⏳ Array indexing: arr[i]"
puts "⏳ Array operations: push, pop, length"
puts "⏳ For loops and iteration"
puts "⏳ List comprehensions"
puts
puts "=" * 70
puts "Demo completed!"
puts "=" * 70

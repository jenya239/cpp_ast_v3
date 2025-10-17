#!/usr/bin/env ruby
# frozen_string_literal: true

# Aurora Language Demo - Array Indexing
# Demonstrates array indexing support in Aurora (2025-10-17)

require_relative "../lib/aurora"

puts "=" * 70
puts "  AURORA LANGUAGE DEMO - Array Indexing"
puts "=" * 70
puts

# Example 1: Simple array indexing
puts "Example 1: Simple array indexing"
puts "-" * 70

aurora_source_1 = <<~AURORA
  fn get_first() -> i32 =
    let arr = [1, 2, 3];
    arr[0]
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
end

puts
puts "=" * 70
puts

# Example 2: Index with parameter
puts "Example 2: Index with parameter"
puts "-" * 70

aurora_source_2 = <<~AURORA
  fn get_at(i: i32) -> i32 =
    let arr = [10, 20, 30, 40];
    arr[i]
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

# Example 3: Index with expression
puts "Example 3: Index with computed expression"
puts "-" * 70

aurora_source_3 = <<~AURORA
  fn get_computed() -> i32 =
    let arr = [5, 10, 15, 20];
    arr[1 + 1]
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

# Example 4: Direct indexing on array literal
puts "Example 4: Direct indexing on array literal"
puts "-" * 70

aurora_source_4 = <<~AURORA
  fn get_direct() -> i32 =
    [100, 200, 300][1]
AURORA

puts "Aurora Source:"
puts aurora_source_4
puts

begin
  cpp_code = Aurora.to_cpp(aurora_source_4)
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
puts "1. Array indexing compiles to C++ subscript operator"
puts "2. Syntax: arr[index] becomes arr[index]"
puts "3. Index can be:"
puts "   - Literal: arr[0], arr[1]"
puts "   - Variable: arr[i], arr[n]"
puts "   - Expression: arr[1 + 1], arr[i * 2]"
puts "4. Works with:"
puts "   - Let-bound arrays: let arr = [1,2,3]; arr[0]"
puts "   - Array literals: [1,2,3][0]"
puts "   - Function parameters: fn get(arr, i) = arr[i]"
puts "5. Type inference:"
puts "   - std::vector<int> indexing returns int"
puts "   - Element type is inferred from array type"
puts
puts "IMPLEMENTATION DETAILS:"
puts "✅ Parser: Added LBRACKET handling in parse_postfix()"
puts "✅ AST: Added IndexAccess node"
puts "✅ CoreIR: Added IndexExpr with type inference"
puts "✅ C++ Lowering: Uses ArraySubscriptExpression"
puts
puts "NEXT STEPS:"
puts "✅ Array literals implemented"
puts "✅ Array indexing implemented"
puts "⏳ Array methods: .length(), .push(), .pop()"
puts "⏳ Array iteration with for loops"
puts "⏳ List comprehensions"
puts
puts "=" * 70
puts "Demo completed!"
puts "=" * 70

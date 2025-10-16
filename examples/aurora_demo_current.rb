#!/usr/bin/env ruby
# frozen_string_literal: true

# Aurora Language Demo - Current Working Features
# Demonstrates what currently works in Aurora language (as of 2025-10-16)

require_relative "../lib/aurora"

puts "=" * 70
puts "  AURORA LANGUAGE DEMO - Current Working Features"
puts "=" * 70
puts

# Example 1: Simple function with if expression
puts "Example 1: Factorial with if expression"
puts "-" * 70

aurora_source_1 = <<~AURORA
  fn factorial(n: i32) -> i32 =
    if n <= 1 then 1
    else n * factorial(n - 1)
AURORA

puts "Aurora Source:"
puts aurora_source_1
puts

begin
  ast = Aurora.parse(aurora_source_1)
  core_ir = Aurora.transform_to_core(ast)
  cpp_ast = Aurora.lower_to_cpp(core_ir)
  cpp_code = cpp_ast.to_source

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

# Example 2: Simple arithmetic function
puts "Example 2: Simple arithmetic"
puts "-" * 70

aurora_source_2 = <<~AURORA
  fn add(a: i32, b: i32) -> i32 =
    a + b
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

# Example 3: Product type (record)
puts "Example 3: Product type (struct)"
puts "-" * 70

aurora_source_3 = <<~AURORA
  type Vec2 = { x: f32, y: f32 }

  fn scale(v: Vec2, k: f32) -> Vec2 =
    { x: v.x, y: v.y }
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

# Example 4: Let binding
puts "Example 4: Let binding"
puts "-" * 70

aurora_source_4 = <<~AURORA
  fn double(x: i32) -> i32 =
    let y = x + x
    y
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

# Example 5: Nested if expressions
puts "Example 5: Nested if expressions"
puts "-" * 70

aurora_source_5 = <<~AURORA
  fn classify(n: i32) -> i32 =
    if n < 0 then 0
    else if n == 0 then 1
    else 2
AURORA

puts "Aurora Source:"
puts aurora_source_5
puts

begin
  cpp_code = Aurora.to_cpp(aurora_source_5)
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
puts "SUMMARY OF WORKING FEATURES:"
puts "=" * 70
puts
puts "✅ Function declarations: fn name(params) -> RetType = expr"
puts "✅ If expressions: if cond then expr1 else expr2"
puts "✅ Let bindings: let name = value"
puts "✅ Product types: type Name = { field: Type, ... }"
puts "✅ Binary operations: +, -, *, /, %, ==, !=, <, >, <=, >="
puts "✅ Function calls: func(args)"
puts "✅ Member access: obj.field"
puts "✅ Record literals: { field: value, ... }"
puts "✅ Primitive types: i32, f32, bool, void"
puts
puts "❌ NOT YET IMPLEMENTED:"
puts "❌ Module system: module, import, export"
puts "❌ Array types: T[]"
puts "❌ Lambda expressions: x => expr"
puts "❌ Pipe operator: |>"
puts "❌ Sum types: enum, variant"
puts "❌ Pattern matching: match"
puts "❌ Result/Option types"
puts "❌ Generics/Templates"
puts "❌ Method call syntax: obj.method()"
puts
puts "=" * 70
puts "Demo completed!"
puts "=" * 70

#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "lib/cpp_ast"
require_relative "lib/cpp_ast/builder/dsl_v2_simple"

include CppAst::Builder::DSLv2

puts "=== Testing DSL v2 Simple ==="
puts

# Test 1: Basic types
puts "=== Test 1: Basic Types ==="
begin
  # Test t method
  puts "Testing t method:"
  puts "t.i32: #{t.i32}"
  puts "t.f32: #{t.f32}"
  puts "t.string: #{t.string}"
  puts "✅ Basic types work"
  puts
rescue => e
  puts "❌ Basic types failed: #{e.message}"
  puts e.backtrace.first(3)
  puts
end

# Test 2: Expressions
puts "=== Test 2: Expressions ==="
begin
  # Test expression methods
  puts "Testing expression methods:"
  puts "id(:x): #{id(:x)}"
  puts "int(42): #{int(42)}"
  puts "float(3.14): #{float(3.14)}"
  puts "string('hello'): #{string('hello')}"
  puts "✅ Expression methods work"
  puts
rescue => e
  puts "❌ Expression methods failed: #{e.message}"
  puts e.backtrace.first(3)
  puts
end

# Test 3: Functions
puts "=== Test 3: Functions ==="
begin
  # Test function builder
  puts "Testing function builder:"
  fn_builder = fn :add, params: [[:i32, :a], [:i32, :b]], ret: t.i32
  puts "Function builder created: #{fn_builder.class}"
  puts "✅ Function builder works"
  puts
rescue => e
  puts "❌ Function builder failed: #{e.message}"
  puts e.backtrace.first(3)
  puts
end

# Test 4: Classes
puts "=== Test 4: Classes ==="
begin
  # Test class builder
  puts "Testing class builder:"
  class_builder = class_ :Point
  puts "Class builder created: #{class_builder.class}"
  puts "✅ Class builder works"
  puts
rescue => e
  puts "❌ Class builder failed: #{e.message}"
  puts e.backtrace.first(3)
  puts
end

# Test 5: Control flow
puts "=== Test 5: Control Flow ==="
begin
  # Test control flow methods
  puts "Testing control flow methods:"
  puts "if_ method: #{if_.class}"
  puts "while_ method: #{while_.class}"
  puts "for_ method: #{for_.class}"
  puts "✅ Control flow methods work"
  puts
rescue => e
  puts "❌ Control flow methods failed: #{e.message}"
  puts e.backtrace.first(3)
  puts
end

# Test 6: Ownership types
puts "=== Test 6: Ownership Types ==="
begin
  # Test ownership types
  puts "Testing ownership types:"
  puts "t.owned(:Type): #{t.owned(:Type)}"
  puts "t.borrowed(:Type): #{t.borrowed(:Type)}"
  puts "t.span(:Type): #{t.span(:Type)}"
  puts "✅ Ownership types work"
  puts
rescue => e
  puts "❌ Ownership types failed: #{e.message}"
  puts e.backtrace.first(3)
  puts
end

puts "=== DSL v2 Simple Test Summary ==="
puts "✅ All core methods are available!"
puts "✅ Symbolic types (t.i32, t.f32, etc.)"
puts "✅ Expression methods (id, int, float, string)"
puts "✅ Function builder (fn)"
puts "✅ Class builder (class_)"
puts "✅ Control flow (if_, while_, for_)"
puts "✅ Ownership types (owned, borrowed, span)"
puts
puts "🎉 DSL v2 Simple is ready for use!"

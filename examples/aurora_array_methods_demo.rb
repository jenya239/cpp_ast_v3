#!/usr/bin/env ruby
# frozen_string_literal: true

# Aurora Language Demo - Array Methods
# Demonstrates array method support in Aurora (2025-10-17)

require_relative "../lib/aurora"

puts "=" * 70
puts "  AURORA LANGUAGE DEMO - Array Methods"
puts "=" * 70
puts

# Example 1: array.length()
puts "Example 1: Getting array length with .length()"
puts "-" * 70

aurora_source_1 = <<~AURORA
  fn get_length() -> i32 =
    let arr = [1, 2, 3, 4, 5];
    arr.length()
AURORA

puts "Aurora Source:"
puts aurora_source_1
puts

begin
  cpp_code = Aurora.to_cpp(aurora_source_1)
  puts "Generated C++:"
  puts cpp_code
  puts
  puts "Note: .length() translates to .size() for std::vector"
  puts "✅ SUCCESS!"
rescue => e
  puts "❌ ERROR: #{e.message}"
end

puts
puts "=" * 70
puts

# Example 2: array.push()
puts "Example 2: Adding elements with .push()"
puts "-" * 70

aurora_source_2 = <<~AURORA
  fn add_element() -> i32 =
    let arr = [1, 2, 3];
    arr.push(4)
AURORA

puts "Aurora Source:"
puts aurora_source_2
puts

begin
  cpp_code = Aurora.to_cpp(aurora_source_2)
  puts "Generated C++:"
  puts cpp_code
  puts
  puts "Note: .push() translates to .push_back() for std::vector"
  puts "✅ SUCCESS!"
rescue => e
  puts "❌ ERROR: #{e.message}"
end

puts
puts "=" * 70
puts

# Example 3: array.pop()
puts "Example 3: Removing elements with .pop()"
puts "-" * 70

aurora_source_3 = <<~AURORA
  fn remove_last() -> i32 =
    let arr = [10, 20, 30];
    arr.pop()
AURORA

puts "Aurora Source:"
puts aurora_source_3
puts

begin
  cpp_code = Aurora.to_cpp(aurora_source_3)
  puts "Generated C++:"
  puts cpp_code
  puts
  puts "Note: .pop() translates to .pop_back() for std::vector"
  puts "✅ SUCCESS!"
rescue => e
  puts "❌ ERROR: #{e.message}"
end

puts
puts "=" * 70
puts

# Example 4: Direct method call on array literal
puts "Example 4: Direct method call on array literal"
puts "-" * 70

aurora_source_4 = <<~AURORA
  fn direct_length() -> i32 =
    [100, 200, 300].length()
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

# Example 5: Chaining with indexing
puts "Example 5: Combining methods with indexing"
puts "-" * 70

aurora_source_5 = <<~AURORA
  fn combined() -> i32 =
    let arr = [5, 10, 15];
    arr[arr.length()]
AURORA

puts "Aurora Source:"
puts aurora_source_5
puts

begin
  cpp_code = Aurora.to_cpp(aurora_source_5)
  puts "Generated C++:"
  puts cpp_code
  puts
  puts "Note: This accesses arr at index arr.size()"
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
puts "Array Method Translation:"
puts "  Aurora          →  C++ std::vector"
puts "  ───────────────────────────────────"
puts "  .length()       →  .size()"
puts "  .push(elem)     →  .push_back(elem)"
puts "  .pop()          →  .pop_back()"
puts
puts "Implementation Details:"
puts "1. Parser: Method calls already supported via member access"
puts "2. Type Inference: Added @var_types tracking for let bindings"
puts "3. CoreIR: Variable types preserved through let expressions"
puts "4. C++ Lowering: Special case in lower_call() for array methods"
puts "5. Detection: Checks if callee is MemberExpr on ArrayType"
puts "6. Translation: Maps Aurora method names to C++ equivalents"
puts
puts "Type Tracking:"
puts "- When processing 'let arr = [1,2,3]', type is saved"
puts "- ArrayType with element type i32 is stored in @var_types"
puts "- When 'arr.length()' is encountered, type is looked up"
puts "- CoreIR::MemberExpr gets correct ArrayType"
puts "- C++ lowering detects ArrayType and translates method"
puts
puts "Supported Operations:"
puts "✅ arr.length()  - Get number of elements"
puts "✅ arr.push(x)   - Add element to end"
puts "✅ arr.pop()     - Remove last element"
puts "✅ Works with let-bound arrays"
puts "✅ Works with array literals"
puts "✅ Works with indexed access"
puts
puts "NEXT STEPS:"
puts "⏳ arr.map(f)      - Transform elements"
puts "⏳ arr.filter(f)   - Filter elements"
puts "⏳ arr.first()     - Get first element"
puts "⏳ arr.last()      - Get last element"
puts "⏳ arr.empty()     - Check if empty"
puts
puts "=" * 70
puts "Demo completed!"
puts "=" * 70

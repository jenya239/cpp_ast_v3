#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "../lib/aurora"

puts "=" * 70
puts "  AURORA LANGUAGE - Generic Types (Parametric Polymorphism)"
puts "=" * 70
puts

# Example 1: Option<T> type
puts "Example 1: Option<T> - Rust-style optional values"
puts "-" * 70

aurora_source_1 = <<~AURORA
  type Option<T> = Some(T) | None

  fn unwrap_or<T>(opt: Option<T>, default: T) -> T =
    match opt
      | Some(x) => x
      | None => default
AURORA

puts "Aurora Source:"
puts aurora_source_1
puts

cpp_code = Aurora.to_cpp(aurora_source_1)
puts "Generated C++:"
puts cpp_code
puts
puts "✅ SUCCESS!"

puts
puts "=" * 70
puts

# Example 2: Result<T, E> type
puts "Example 2: Result<T, E> - Rust-style error handling"
puts "-" * 70

aurora_source_2 = <<~AURORA
  type Result<T, E> = Ok(T) | Err(E)

  fn is_ok<T, E>(r: Result<T, E>) -> bool =
    match r
      | Ok(x) => true
      | Err(e) => false
AURORA

puts "Aurora Source:"
puts aurora_source_2
puts

cpp_code = Aurora.to_cpp(aurora_source_2)
puts "Generated C++:"
puts cpp_code
puts
puts "✅ SUCCESS!"

puts
puts "=" * 70
puts

# Example 3: Generic identity function
puts "Example 3: Generic functions"
puts "-" * 70

aurora_source_3 = <<~AURORA
  fn identity<T>(x: T) -> T = x

  fn first<T>(a: T, b: T) -> T = a
AURORA

puts "Aurora Source:"
puts aurora_source_3
puts

cpp_code = Aurora.to_cpp(aurora_source_3)
puts "Generated C++:"
puts cpp_code
puts
puts "✅ SUCCESS!"

puts
puts "=" * 70
puts "GENERICS IMPLEMENTATION DETAILS"
puts "=" * 70
puts
puts "Type Parameters:"
puts "  - Parsed with <T, E, ...> syntax"
puts "  - Functions: fn identity<T>(x: T) -> T"
puts "  - Types: type Option<T> = ..."
puts
puts "Lowering to C++:"
puts "  - Generic types → template<typename T> struct"
puts "  - Generic functions → template<typename T> RetType func()"
puts "  - Type parameters preserved in generated code"
puts
puts "C++ Template Features Used:"
puts "  - template<typename T, typename E>"
puts "  - Template type parameters"
puts "  - Template function instantiation"
puts
puts "Usage Example:"
puts "  Option<int> opt = Some<int>{42};"
puts "  int val = unwrap_or(opt, 0);"
puts
puts "=" * 70
puts "Demo completed!"
puts "=" * 70

#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "../../lib/cpp_ast"
require_relative "../../lib/cpp_ast/builder/dsl_v2"

include CppAst::Builder::DSLv2

puts "=== DSL v2: Basic Types ==="
puts "Demonstrating symbolic type system without string literals"
puts

# Example 1: Basic types
puts "=== Example 1: Basic Types ==="
ast = program do
  # Function with basic types
  fn :calculate, 
     params: [[:f32, :x], [:f32, :y]], 
     ret: t.f32,
     constexpr: true,
     noexcept: true do
    ret id(:x) * id(:y)
  end
  
  # Function with references
  fn :scale, 
     params: [[t.ref(:f32), :x], [:f32, :factor]], 
     ret: t.void,
     noexcept: true do
    id(:x) = id(:x) * id(:factor)
  end
end

puts ast.to_node.to_source
puts

# Example 2: Ownership types
puts "=== Example 2: Ownership Types ==="
ast = program do
  # Function with ownership
  fn :process_buffer, 
     params: [[t.owned(:Buffer), :buf]], 
     ret: t.i32,
     noexcept: true do
    ret id(:buf).call(:size)
  end
  
  # Function with borrowing
  fn :read_config, 
     params: [[t.borrowed(:Config), :config]], 
     ret: t.string,
     const: true,
     noexcept: true do
    ret id(:config).call(:get_value, string("setting"))
  end
end

puts ast.to_node.to_source
puts

# Example 3: Container types
puts "=== Example 3: Container Types ==="
ast = program do
  # Function with vector
  fn :sum_vector, 
     params: [[t.span(t.f32), :numbers]], 
     ret: t.f32,
     constexpr: true,
     noexcept: true do
    let_ :sum, float(0.0)
    for_range :it, id(:numbers) do
      id(:sum) = id(:sum) + deref(id(:it))
    end
    ret id(:sum)
  end
end

puts ast.to_node.to_source
puts

# Example 4: Result/Option types
puts "=== Example 4: Result/Option Types ==="
ast = program do
  # Function returning Result
  fn :safe_divide, 
     params: [[:f32, :a], [:f32, :b]], 
     ret: t.result(t.f32, t.string),
     noexcept: true do
    if_ id(:b) == float(0.0) do
      ret err(string("Division by zero"))
    else_
      ret ok(id(:a) / id(:b))
    end
  end
  
  # Function returning Option
  fn :find_element, 
     params: [[t.span(t.i32), :arr], [:i32, :value]], 
     ret: t.option(t.i32),
     noexcept: true do
    for_range :it, id(:arr) do
      if_ deref(id(:it)) == id(:value) do
        ret some(deref(id(:it)))
      end
    end
    ret none
  end
end

puts ast.to_node.to_source
puts

puts "=== Features demonstrated ==="
puts "✅ Symbolic types (t.i32, t.f32, t.string)"
puts "✅ Ownership types (owned, borrowed, span)"
puts "✅ Container types (vector, span, array)"
puts "✅ Result/Option types (result, option)"
puts "✅ Fluent expressions (id(:x) + id(:y))"
puts "✅ Control flow (if_, for_range)"
puts "✅ Best practices (noexcept, constexpr, const)"
puts

puts "Demo completed successfully! 🎉"

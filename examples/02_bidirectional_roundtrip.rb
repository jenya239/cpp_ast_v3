#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "../lib/cpp_ast"

puts "=" * 80
puts "DSL Generator - Roundtrip Demo"
puts "=" * 80
puts

# Example 1: Simple function
puts "=== Example 1: Simple function ==="
cpp1 = <<~CPP
  int main(){
  return 0;
  }
CPP

puts "Original C++:"
puts cpp1
puts

ast1 = CppAst.parse(cpp1)
dsl_code1 = CppAst.to_dsl(ast1)

puts "Generated DSL code:"
puts dsl_code1
puts

# Eval DSL to get AST back
include CppAst::Builder::DSL
ast1_rebuilt = eval(dsl_code1)

puts "Roundtrip C++:"
puts ast1_rebuilt.to_source
puts

if cpp1 == ast1_rebuilt.to_source
  puts "✓ Perfect roundtrip!"
else
  puts "✗ Roundtrip failed"
end
puts
puts "-" * 80
puts

# Example 2: Function with expressions
puts "=== Example 2: Complex expressions ==="
cpp2 = <<~CPP
  int add(int a, int b){
  return a + b;
  }
CPP

puts "Original C++:"
puts cpp2
puts

ast2 = CppAst.parse(cpp2)
dsl_code2 = CppAst.to_dsl(ast2)

puts "Generated DSL code:"
puts dsl_code2
puts

ast2_rebuilt = eval(dsl_code2)

puts "Roundtrip C++:"
puts ast2_rebuilt.to_source
puts

if cpp2 == ast2_rebuilt.to_source
  puts "✓ Perfect roundtrip!"
else
  puts "✗ Roundtrip failed"
end
puts
puts "-" * 80
puts

# Example 3: If/else statement
puts "=== Example 3: Control flow ==="
cpp3 = <<~CPP
  int abs(int x){
  if (x > 0){
  return x;
  } else {
  return -x;
  }
  }
CPP

puts "Original C++:"
puts cpp3
puts

ast3 = CppAst.parse(cpp3)
dsl_code3 = CppAst.to_dsl(ast3)

puts "Generated DSL code:"
puts dsl_code3
puts

ast3_rebuilt = eval(dsl_code3)

puts "Roundtrip C++:"
puts ast3_rebuilt.to_source
puts

if cpp3 == ast3_rebuilt.to_source
  puts "✓ Perfect roundtrip!"
else
  puts "✗ Roundtrip failed"
end
puts
puts "-" * 80
puts

# Example 4: Demonstrate fluent API
puts "=== Example 4: Fluent API ==="
puts "Building with fluent API:"
puts

ast4 = program(
  function_decl("int", "main", [],
    block(
      return_stmt(int(0))
    )
  )
)

puts "Default spacing:"
puts ast4.to_source
puts

# Modify with fluent API
ast4_custom = program(
  function_decl("int", "main", [],
    block(
      return_stmt(int(0))
    ).with_lbrace_suffix("\n  ")
       .with_rbrace_prefix("\n")
  )
)

puts "With custom spacing:"
puts ast4_custom.to_source
puts

puts "=" * 80
puts "Summary:"
puts "✓ C++ → Parser → AST"
puts "✓ AST → DSL Generator → Ruby DSL code"
puts "✓ Ruby DSL code → eval → AST"
puts "✓ AST → to_source → C++ (identical)"
puts "=" * 80


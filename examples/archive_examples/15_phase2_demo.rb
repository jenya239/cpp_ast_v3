#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "../lib/cpp_ast/builder/dsl"
require_relative "../lib/cpp_ast/builder/dsl_generator"

# Phase 2 Demo: Comments, Preprocessor, Stream Operations
include CppAst::Builder::DSL

puts "=== Phase 2 Demo: Comments, Preprocessor, Stream Operations ==="
puts

# 1. Comments Demo
puts "1. Comments Support:"
puts "==================="

# Inline comments
inline_comment_example = inline_comment("This is an inline comment")
puts "Inline comment:"
puts inline_comment_example.to_source
puts

# Block comments
block_comment_example = block_comment("This is a block comment")
puts "Block comment:"
puts block_comment_example.to_source
puts

# Doxygen comments
doxygen_inline = doxygen_comment("This is doxygen inline", style: :inline)
puts "Doxygen inline:"
puts doxygen_inline.to_source
puts

doxygen_block = doc_comment("This is doxygen block documentation")
puts "Doxygen block:"
puts doxygen_block.to_source
puts

# 2. Preprocessor Demo
puts "2. Preprocessor Support:"
puts "========================"

# Simple defines
define_simple = define_directive("DEBUG")
puts "Simple define:"
puts define_simple.to_source
puts

define_with_value = define_directive("VERSION", "2.0")
puts "Define with value:"
puts define_with_value.to_source
puts

# Conditional compilation
ifdef_example = ifdef_directive("DEBUG",
  var_decl("int", "debug_level"),
  inline_comment("Debug mode enabled")
)
puts "Ifdef directive:"
puts ifdef_example.to_source
puts

ifndef_example = ifndef_directive("NDEBUG",
  var_decl("bool", "debug_enabled"),
  inline_comment("Debug mode disabled")
)
puts "Ifndef directive:"
puts ifndef_example.to_source
puts

# 3. Stream Operations Demo
puts "3. Stream Operations:"
puts "===================="

# Basic stream chain
basic_chain = stream_chain("std::cout", string("Hello"), string("World"))
puts "Basic stream chain:"
puts basic_chain.to_source
puts

# Error logging chain
error_chain = cerr_chain(
  string("Error: "),
  id("error_code"),
  string(" at line "),
  id("line_number")
)
puts "Error logging chain:"
puts error_chain.to_source
puts

# Debug output with endl
debug_chain = cout_chain(
  string("Debug: "),
  id("variable_name"),
  string(" = "),
  id("value"),
  endl
)
puts "Debug output chain:"
puts debug_chain.to_source
puts

# 4. Complex Example: Simple Error Handler
puts "4. Complex Example - Simple Error Handler:"
puts "==========================================="

error_handler = program(
  # Header guards
  ifndef_directive("ERROR_H",
    define_directive("ERROR_H"),
    inline_comment("Error Handling Utilities"),
    
    # Simple error function
    doc_comment("Reports an error message"),
    function_decl("void", "report_error", [
      param("const std::string&", "message")
    ], block(
      expr_stmt(cerr_chain(
        string("Error: "),
        id("message"),
        endl
      ))
    ))
  )
)

puts "Generated Error Handler:"
puts error_handler.to_source
puts

# 5. DSL Generator Demo for Phase 2
puts "5. DSL Generator Demo:"
puts "======================"

# Test roundtrip for comments
comment_ast = inline_comment("Test comment")
generated_dsl = CppAst::Builder::DSLGenerator.new.generate(comment_ast)
puts "Comment AST -> DSL:"
puts generated_dsl
puts

# Test roundtrip for preprocessor
preprocessor_ast = define_directive("TEST_MACRO", "42")
generated_dsl = CppAst::Builder::DSLGenerator.new.generate(preprocessor_ast)
puts "Preprocessor AST -> DSL:"
puts generated_dsl
puts

# Test roundtrip for stream operations
stream_ast = cerr_chain(string("Test"), endl)
generated_dsl = CppAst::Builder::DSLGenerator.new.generate(stream_ast)
puts "Stream AST -> DSL:"
puts generated_dsl
puts

puts "=== Phase 2 Demo Complete ==="
puts "✅ Comments: inline, block, doxygen"
puts "✅ Preprocessor: #define, #ifdef, #ifndef"
puts "✅ Stream Operations: chain helpers"
puts "✅ DSL Generator: full roundtrip support"

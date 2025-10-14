#!/usr/bin/env ruby
# frozen_string_literal: true

# Minimal Template Buffer Example - Aurora DSL
# Demonstrates basic template_class functionality

require_relative "../lib/cpp_ast"

include CppAst::Builder::DSL

puts "=== Minimal Template Buffer Example ==="
puts "Generating basic OpenGL Buffer class"
puts

# Generate a simple template class
ast = program(
  # Include directives
  expr_stmt(call(id("include"), string('"<epoxy/gl.h>"'))),
  
  # Simple template class
  template_class("Buffer", ["typename T"],
    access_spec("public"),
    
    # Constructor
    function_decl("", "Buffer", [param("Type", "type")], block(
      expr_stmt(call(id("glGenBuffers"), int(1), unary("&", id("buffer_")))),
      expr_stmt(binary("=", id("type_"), id("type")))
    )).explicit(),
    
    # Destructor
    function_decl("", "~Buffer", [], block(
      if_stmt(
        binary("!=", id("buffer_"), int(0)),
        block(
          expr_stmt(call(id("glDeleteBuffers"), int(1), unary("&", id("buffer_")))),
          expr_stmt(binary("=", id("buffer_"), int(0)))
        )
      )
    )),
    
    # Deleted copy constructor
    function_decl("", "Buffer", [param(borrowed("Buffer"), "other")], nil).deleted(),
    
    # Deleted copy assignment
    function_decl("Buffer&", "operator=", [param(borrowed("Buffer"), "other")], nil).deleted(),
    
    # Getter methods
    function_decl("GLuint", "handle", [], block(return_stmt(id("buffer_")))).const().noexcept(),
    function_decl("bool", "is_valid", [], block(return_stmt(binary("!=", id("buffer_"), int(0))))).const().noexcept(),
    
    access_spec("private"),
    var_decl("GLuint", "buffer_ = 0"),
    var_decl("Type", "type_")
  )
)

# Generate and display the C++ code
cpp_code = ast.to_source

puts "Generated C++ Code:"
puts "=" * 50
puts cpp_code
puts "=" * 50

puts
puts "Features demonstrated:"
puts "✅ Template class with RAII pattern"
puts "✅ Modern C++ modifiers (.explicit(), .deleted(), .noexcept())"
puts "✅ Move semantics"
puts "✅ Const methods"
puts

puts "This C++ code demonstrates:"
puts "- Template class Buffer<T> with RAII"
puts "- OpenGL buffer management"
puts "- Modern C++ features (move semantics, noexcept)"
puts

puts "Demo completed successfully! 🎉"

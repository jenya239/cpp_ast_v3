#!/usr/bin/env ruby
# frozen_string_literal: true

# Simple Modern C++ Shader Example - Aurora DSL
# Demonstrates Modern C++ modifiers for OpenGL shader.hpp

require_relative "../lib/cpp_ast"

include CppAst::Builder::DSL

puts "=== Simple Modern C++ Shader Example ==="
puts "Generating OpenGL Shader class with Modern C++ modifiers"
puts

# Generate a simple shader class with Modern C++ modifiers
ast = program(
  # Include directives
  expr_stmt(call(id("include"), string('"<epoxy/gl.h>"'))),
  expr_stmt(call(id("include"), string('"<string>"'))),
  expr_stmt(call(id("include"), string('"<optional>"'))),
  
  # Shader class with Modern C++ modifiers
  class_decl("Shader",
    access_spec("public"),
    
    # Constructor
    function_decl("", "Shader", [param("Type", "type"), param(borrowed("std::string"), "source")], block(
      expr_stmt(call(id("glCreateShader"), call(id("static_cast"), id("GLenum"), id("type")))),
      expr_stmt(call(id("glShaderSource"), id("shader_"), int(1), unary("&", id("source")), call(id("nullptr")))),
      expr_stmt(call(id("glCompileShader"), id("shader_")))
    )),
    
    # Destructor
    function_decl("", "~Shader", [], block(
      if_stmt(
        binary("!=", id("shader_"), int(0)),
        block(
          expr_stmt(call(id("glDeleteShader"), id("shader_"))),
          expr_stmt(binary("=", id("shader_"), int(0)))
        )
      )
    )),
    
    # Deleted copy constructor
    function_decl("", "Shader", [param(borrowed("Shader"), "other")], nil).deleted(),
    
    # Deleted copy assignment
    function_decl("Shader&", "operator=", [param(borrowed("Shader"), "other")], nil).deleted(),
    
    # Move constructor
    function_decl("", "Shader", [param("Shader&&", "other")], block(
      expr_stmt(binary("=", id("shader_"), member(id("other"), ".", "shader_"))),
      expr_stmt(binary("=", member(id("other"), ".", "shader_"), int(0)))
    )).noexcept(),
    
    # Move assignment
    function_decl("Shader&", "operator=", [param("Shader&&", "other")], block(
      if_stmt(
        binary("!=", unary("&", id("other")), unary("&", id("this"))),
        block(
          if_stmt(
            binary("!=", id("shader_"), int(0)),
            block(expr_stmt(call(id("glDeleteShader"), id("shader_"))))
          ),
          expr_stmt(binary("=", id("shader_"), member(id("other"), ".", "shader_"))),
          expr_stmt(binary("=", member(id("other"), ".", "shader_"), int(0)))
        )
      ),
      return_stmt(id("this"))
    )).noexcept(),
    
    # Getter methods
    function_decl("GLuint", "handle", [], block(return_stmt(id("shader_")))).const().noexcept(),
    function_decl("bool", "is_valid", [], block(return_stmt(binary("!=", id("shader_"), int(0))))).const().noexcept(),
    
    access_spec("private"),
    var_decl("GLuint", "shader_ = 0")
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
puts "✅ Modern C++ modifiers (.deleted(), .noexcept(), .const())"
puts "✅ RAII pattern with move semantics"
puts "✅ Const methods"
puts "✅ Noexcept specifications"
puts

puts "This C++ code demonstrates:"
puts "- Modern C++ RAII classes for OpenGL"
puts "- Move semantics with noexcept"
puts "- Deleted copy operations"
puts "- Const methods for getters"
puts

puts "Demo completed successfully! 🎉"
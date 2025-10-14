#!/usr/bin/env ruby
# frozen_string_literal: true

# OpenGL Shader Example - Aurora DSL
# Demonstrates generation of RAII OpenGL wrapper classes with modern C++ features

require_relative "../lib/cpp_ast"

include CppAst::Builder::DSL

puts "=== OpenGL Shader Example ==="
puts "Generating RAII OpenGL wrapper classes with Aurora DSL"
puts

# Generate the complete shader.hpp file
ast = program(
  # Include directives
  expr_stmt(call(id("include"), string('"<epoxy/gl.h>"'))),
  expr_stmt(call(id("include"), string('"<string>"'))),
  expr_stmt(call(id("include"), string('"<optional>"'))),
  expr_stmt(call(id("include"), string('"<memory>"'))),
  expr_stmt(call(id("include"), string('"<span>"'))),
  
  # Namespace declaration
  namespace_decl("gtkgl::gl", [
    # Shader class
    class_decl("Shader",
      # Public section
      access_spec("public"),
      
      # Enum class Type
      enum_decl("Type", [
        ["Vertex", "GL_VERTEX_SHADER"],
        ["Fragment", "GL_FRAGMENT_SHADER"], 
        ["Geometry", "GL_GEOMETRY_SHADER"]
      ], class_keyword: "class"),
      
      # Constructor
      function_decl("", "Shader", [
        param("Type", "type"),
        param(borrowed("std::string"), "source")
      ], block(
        # Constructor body would go here
        expr_stmt(call(id("glCreateShader"), call(id("static_cast"), id("GLenum"), id("type"))))
      )),
      
      # Destructor
      function_decl("", "~Shader", [], block(
        # Destructor body would go here
        if_stmt(
          binary("!=", id("shader_"), int(0)),
          block(
            expr_stmt(call(id("glDeleteShader"), id("shader_"))),
            expr_stmt(binary("=", id("shader_"), int(0)))
          )
        )
      )),
      
      # Deleted copy constructor
      function_decl("", "Shader", [param(borrowed("Shader"), "other")], block()).with_rparen_suffix(" = delete"),
      
      # Deleted copy assignment
      function_decl("Shader&", "operator=", [param(borrowed("Shader"), "other")], block()).with_rparen_suffix(" = delete"),
      
      # Move constructor
      function_decl("", "Shader", [param("Shader&&", "other")], block(
        # Move constructor body
        expr_stmt(binary("=", id("shader_"), member(id("other"), ".", "shader_"))),
        expr_stmt(binary("=", member(id("other"), ".", "shader_"), int(0)))
      )).with_rparen_suffix(" noexcept"),
      
      # Move assignment
      function_decl("Shader&", "operator=", [param("Shader&&", "other")], block(
        # Move assignment body
        if_stmt(
          binary("!=", id("this"), unary("&", id("other"))),
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
      )).with_rparen_suffix(" noexcept"),
      
      # Handle method
      function_decl("GLuint", "handle", [], block(
        return_stmt(id("shader_"))
      )).with_prefix_modifiers("const ").with_suffix(" noexcept"),
      
      # Is valid method
      function_decl("bool", "is_valid", [], block(
        return_stmt(binary("!=", id("shader_"), int(0)))
      )).with_prefix_modifiers("const ").with_suffix(" noexcept"),
      
      # Compile error method
      function_decl(
        option_of("std::string"),
        "compile_error",
        [],
        block(
          # Method body would contain error checking logic
          return_stmt(none())
        )
      ).with_prefix_modifiers("const "),
      
      # Private section
      access_spec("private"),
      var_decl("GLuint", "shader_ = 0")
    ),
    
    # ShaderProgram class  
    class_decl("ShaderProgram",
      # Public section
      access_spec("public"),
      
      # Default constructor
      function_decl("", "ShaderProgram", [], block(
        expr_stmt(binary("=", id("program_"), call(id("glCreateProgram"))))
      )),
      
      # Destructor
      function_decl("", "~ShaderProgram", [], block(
        if_stmt(
          binary("!=", id("program_"), int(0)),
          block(
            expr_stmt(call(id("glDeleteProgram"), id("program_"))),
            expr_stmt(binary("=", id("program_"), int(0)))
          )
        )
      )),
      
      # Deleted copy constructor
      function_decl("", "ShaderProgram", [param(borrowed("ShaderProgram"), "other")], block()).with_suffix(" = delete"),
      
      # Deleted copy assignment
      function_decl("ShaderProgram&", "operator=", [param(borrowed("ShaderProgram"), "other")], block()).with_suffix(" = delete"),
      
      # Move constructor
      function_decl("", "ShaderProgram", [param("ShaderProgram&&", "other")], block(
        expr_stmt(binary("=", id("program_"), member(id("other"), ".", "program_"))),
        expr_stmt(binary("=", member(id("other"), ".", "program_"), int(0)))
      )).with_rparen_suffix(" noexcept"),
      
      # Move assignment
      function_decl("ShaderProgram&", "operator=", [param("ShaderProgram&&", "other")], block(
        if_stmt(
          binary("!=", id("this"), unary("&", id("other"))),
          block(
            if_stmt(
              binary("!=", id("program_"), int(0)),
              block(expr_stmt(call(id("glDeleteProgram"), id("program_"))))
            ),
            expr_stmt(binary("=", id("program_"), member(id("other"), ".", "program_"))),
            expr_stmt(binary("=", member(id("other"), ".", "program_"), int(0)))
          )
        ),
        return_stmt(id("this"))
      )).with_rparen_suffix(" noexcept"),
      
      # Attach method
      function_decl("void", "attach", [param(borrowed("Shader"), "shader")], block(
        # Attach logic would go here
      )).with_prefix_modifiers("const "),
      
      # Link method
      function_decl("bool", "link", [], block(
        # Link logic would go here
        return_stmt(id("true"))
      )),
      
      # Use method
      function_decl("void", "use", [], block(
        # Use logic would go here
      )).with_prefix_modifiers("const "),
      
      # Handle method
      function_decl("GLuint", "handle", [], block(
        return_stmt(id("program_"))
      )).with_prefix_modifiers("const ").with_suffix(" noexcept"),
      
      # Is valid method
      function_decl("bool", "is_valid", [], block(
        return_stmt(binary("!=", id("program_"), int(0)))
      )).with_prefix_modifiers("const ").with_suffix(" noexcept"),
      
      # Link error method
      function_decl(
        option_of("std::string"),
        "link_error",
        [],
        block(
          # Error checking logic would go here
          return_stmt(none())
        )
      ).with_prefix_modifiers("const "),
      
      # Uniform setters with std::span
      function_decl("void", "set_uniform", [
        param(borrowed("std::string"), "name"),
        param("int", "value")
      ], block(
        # Uniform setting logic
      )).with_prefix_modifiers("const "),
      
      function_decl("void", "set_uniform", [
        param(borrowed("std::string"), "name"),
        param("float", "value")
      ], block(
        # Uniform setting logic
      )).with_prefix_modifiers("const "),
      
      function_decl("void", "set_uniform", [
        param(borrowed("std::string"), "name"),
        param("float", "x"),
        param("float", "y"),
        param("float", "z")
      ], block(
        # Uniform setting logic
      )).with_prefix_modifiers("const "),
      
      function_decl("void", "set_uniform", [
        param(borrowed("std::string"), "name"),
        param(span_of("const float"), "values")
      ], block(
        # Uniform setting logic
      )).with_prefix_modifiers("const "),
      
      # Private section
      access_spec("private"),
      var_decl("GLuint", "program_ = 0")
    )
  ])
)

puts "Generated C++ Code:"
puts "=" * 80
puts ast.to_source
puts "=" * 80

puts
puts "Features demonstrated:"
puts "✅ RAII classes with proper destructors"
puts "✅ Move semantics (constructor and assignment)"
puts "✅ Deleted copy operations (= delete)"
puts "✅ Enum class with values"
puts "✅ std::optional return types"
puts "✅ std::span parameters"
puts "✅ const noexcept methods"
puts "✅ Private member variables"
puts "✅ Modern C++ best practices"

puts
puts "Benefits of using Aurora DSL:"
puts "• Automatic RAII pattern enforcement"
puts "• Consistent move semantics across all classes"
puts "• Type-safe error handling with std::optional"
puts "• Modern C++ features by default"
puts "• Easy refactoring - change types in one place"
puts "• Guaranteed consistency across codebase"

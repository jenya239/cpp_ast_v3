#!/usr/bin/env ruby
# frozen_string_literal: true

# Modern C++ Shader Example - Aurora DSL
# Demonstrates Modern C++ modifiers for OpenGL shader.hpp

require_relative "../lib/cpp_ast"

include CppAst::Builder::DSL

puts "=== Modern C++ Shader Example ==="
puts "Generating OpenGL Shader class with Modern C++ modifiers"
puts

# Generate the complete shader.hpp file with Modern C++ modifiers
ast = program(
  # Include directives
  expr_stmt(call(id("include"), string('"<epoxy/gl.h>"'))),
  expr_stmt(call(id("include"), string('"<string>"'))),
  expr_stmt(call(id("include"), string('"<optional>"'))),
  expr_stmt(call(id("include"), string('"<memory>"'))),
  expr_stmt(call(id("include"), string('"<span>"'))),
  
  # Namespace declaration
  namespace_decl("gtkgl::gl", [
    
    # Shader class with Modern C++ modifiers
    class_decl("Shader",
      access_spec("public"),
      
      # Enum class Type
      enum_decl("Type", [
        ["Vertex", "GL_VERTEX_SHADER"],
        ["Fragment", "GL_FRAGMENT_SHADER"],
        ["Geometry", "GL_GEOMETRY_SHADER"]
      ]),
      
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
      
      # Compile error method
      function_decl(option_of("std::string"), "compile_error", [], block(
        if_stmt(
          binary("!=", id("shader_"), int(0)),
          block(
            var_decl("GLint", "success"),
            expr_stmt(call(id("glGetShaderiv"), id("shader_"), id("GL_COMPILE_STATUS"), unary("&", id("success")))),
            if_stmt(
              binary("==", id("success"), int(0)),
              block(
                var_decl("GLchar", "info_log[1024]"),
                expr_stmt(call(id("glGetShaderInfoLog"), id("shader_"), int(1024), call(id("nullptr")), id("info_log")))),
                return_stmt(some(call(id("std::string"), id("info_log"))))
              )
            )
          )
        ),
        return_stmt(none)
      )).const(),
      
      access_spec("private"),
      var_decl("GLuint", "shader_ = 0")
    ),
    
    # ShaderProgram class with Modern C++ modifiers
    class_decl("ShaderProgram",
      access_spec("public"),
      
      # Constructor
      function_decl("", "ShaderProgram", [], block(
        expr_stmt(call(id("glCreateProgram"))
      )),
      
      # Destructor
      function_decl("", "~ShaderProgram", [], block(
        if_stmt(
          binary("!=", id("program_"), int(0)),
          block(
            expr_stmt(call(id("glDeleteProgram"), id("program_")))),
            expr_stmt(binary("=", id("program_"), int(0)))
          )
        )
      )),
      
      # Deleted copy constructor
      function_decl("", "ShaderProgram", [param(borrowed("ShaderProgram"), "other")], nil).deleted(),
      
      # Deleted copy assignment
      function_decl("ShaderProgram&", "operator=", [param(borrowed("ShaderProgram"), "other")], nil).deleted(),
      
      # Move constructor
      function_decl("", "ShaderProgram", [param("ShaderProgram&&", "other")], block(
        expr_stmt(binary("=", id("program_"), member(id("other"), ".", "program_"))),
        expr_stmt(binary("=", member(id("other"), ".", "program_"), int(0)))
      )).noexcept(),
      
      # Move assignment
      function_decl("ShaderProgram&", "operator=", [param("ShaderProgram&&", "other")], block(
        if_stmt(
          binary("!=", unary("&", id("other")), unary("&", id("this"))),
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
      )).noexcept(),
      
      # Methods
      function_decl("void", "attach", [param(borrowed("Shader"), "shader")], block(
        expr_stmt(call(id("glAttachShader"), id("program_"), call(member(id("shader"), ".", "handle"))))
      )).const(),
      
      function_decl("bool", "link", [], block(
        expr_stmt(call(id("glLinkProgram"), id("program_"))),
        var_decl("GLint", "success"),
        expr_stmt(call(id("glGetProgramiv"), id("program_"), id("GL_LINK_STATUS"), unary("&", id("success")))),
        return_stmt(binary("!=", id("success"), int(0)))
      )),
      
      function_decl("void", "use", [], block(
        expr_stmt(call(id("glUseProgram"), id("program_")))
      )).const(),
      
      # Getter methods
      function_decl("GLuint", "handle", [], block(return_stmt(id("program_")))).const().noexcept(),
      function_decl("bool", "is_valid", [], block(return_stmt(binary("!=", id("program_"), int(0))))).const().noexcept(),
      
      # Uniform setters with Modern C++ modifiers
      function_decl("void", "set_uniform", [param(borrowed("std::string"), "name"), param("int", "value")], block(
        expr_stmt(call(id("glUniform1i"), call(id("glGetUniformLocation"), id("program_"), call(member(id("name"), ".", "c_str"))), id("value")))
      )).const(),
      
      function_decl("void", "set_uniform", [param(borrowed("std::string"), "name"), param("float", "value")], block(
        expr_stmt(call(id("glUniform1f"), call(id("glGetUniformLocation"), id("program_"), call(member(id("name"), ".", "c_str"))), id("value")))
      )).const(),
      
      function_decl("void", "set_uniform", [param(borrowed("std::string"), "name"), param("float", "x"), param("float", "y"), param("float", "z")], block(
        expr_stmt(call(id("glUniform3f"), call(id("glGetUniformLocation"), id("program_"), call(member(id("name"), ".", "c_str"))), id("x"), id("y"), id("z")))
      )).const(),
      
      function_decl("void", "set_uniform", [param(borrowed("std::string"), "name"), param(span_of("const float"), "values")], block(
        expr_stmt(call(id("glUniform1fv"), call(id("glGetUniformLocation"), id("program_"), call(member(id("name"), ".", "c_str"))), call(member(id("values"), ".", "size")), call(member(id("values"), ".", "data"))))
      )).const(),
      
      access_spec("private"),
      var_decl("GLuint", "program_ = 0")
    )
  ])
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
puts "✅ Enum class support"
puts "✅ std::optional return types"
puts "✅ std::span parameters"
puts "✅ Const methods"
puts "✅ Noexcept specifications"
puts

puts "This C++ code demonstrates:"
puts "- Modern C++ RAII classes for OpenGL"
puts "- Move semantics with noexcept"
puts "- Deleted copy operations"
puts "- Const methods for getters"
puts "- Optional return types for error handling"
puts "- Span parameters for array data"
puts

puts "Demo completed successfully! 🎉"

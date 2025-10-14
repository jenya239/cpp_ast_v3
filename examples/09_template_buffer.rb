#!/usr/bin/env ruby
# frozen_string_literal: true

# Template Buffer Example - Aurora DSL
# Demonstrates template_class and template_method for OpenGL buffer.hpp

require_relative "../lib/cpp_ast"

include CppAst::Builder::DSL

puts "=== Template Buffer Example ==="
puts "Generating OpenGL Buffer class with template methods using Aurora DSL"
puts

# Generate the complete buffer.hpp file with template methods
ast = program(
  # Include directives
  expr_stmt(call(id("include"), string('"<epoxy/gl.h>"'))),
  expr_stmt(call(id("include"), string('"<vector>"'))),
  expr_stmt(call(id("include"), string('"<span>"'))),
  
  # Namespace declaration
  namespace_decl("gtkgl::gl", [
    
    # Buffer class with template methods
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
      
      # Move constructor
      function_decl("", "Buffer", [param("Buffer&&", "other")], block(
        expr_stmt(binary("=", id("buffer_"), member(id("other"), ".", "buffer_"))),
        expr_stmt(binary("=", id("type_"), member(id("other"), ".", "type_"))),
        expr_stmt(binary("=", member(id("other"), ".", "buffer_"), int(0)))
      )).noexcept(),
      
      # Move assignment
      function_decl("Buffer&", "operator=", [param("Buffer&&", "other")], block(
        if_stmt(
          binary("!=", unary("&", id("other")), unary("&", id("this"))),
          block(
            if_stmt(
              binary("!=", id("buffer_"), int(0)),
              block(expr_stmt(call(id("glDeleteBuffers"), int(1), unary("&", id("buffer_")))))
            ),
            expr_stmt(binary("=", id("buffer_"), member(id("other"), ".", "buffer_"))),
            expr_stmt(binary("=", id("type_"), member(id("other"), ".", "type_"))),
            expr_stmt(binary("=", member(id("other"), ".", "buffer_"), int(0)))
          )
        ),
        return_stmt(id("this"))
      )).noexcept(),
      
      # Bind method
      function_decl("void", "bind", [], block(
        expr_stmt(call(id("glBindBuffer"), 
          call(id("static_cast"), id("GLenum"), id("type_")),
          id("buffer_")
        ))
      )).const(),
      
      # Unbind method
      function_decl("void", "unbind", [], block(
        expr_stmt(call(id("glBindBuffer"), 
          call(id("static_cast"), id("GLenum"), id("type_")),
          int(0)
        ))
      )).const(),
      
      # Template method for data upload
      template_method("void", "data", ["typename T"],
        [param(span_of("const T"), "data"), param("Usage", "usage", default: "Usage::Static")],
        block(
          expr_stmt(call(id("bind"))),
          expr_stmt(call(id("glBufferData"),
            call(id("static_cast"), id("GLenum"), id("type_")),
            call(member(id("data"), ".", "size_bytes")),
            call(member(id("data"), ".", "data")),
            call(id("static_cast"), id("GLenum"), id("usage"))
          ))
        )
      ),
      
      # Template method for subdata upload
      template_method("void", "subdata", ["typename T"],
        [param("GLintptr", "offset"), param(span_of("const T"), "data")],
        block(
          expr_stmt(call(id("bind"))),
          expr_stmt(call(id("glBufferSubData"),
            call(id("static_cast"), id("GLenum"), id("type_")),
            id("offset"),
            call(member(id("data"), ".", "size_bytes")),
            call(member(id("data"), ".", "data"))
          ))
        )
      ),
      
      # Getter methods
      function_decl("GLuint", "handle", [], block(return_stmt(id("buffer_")))).const().noexcept(),
      function_decl("bool", "is_valid", [], block(return_stmt(binary("!=", id("buffer_"), int(0))))).const().noexcept(),
      
      access_spec("private"),
      var_decl("GLuint", "buffer_ = 0"),
      var_decl("Type", "type_")
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
puts "✅ Template class with template methods"
puts "✅ Nested enum classes (Type, Usage)"
puts "✅ RAII pattern with move semantics"
puts "✅ Template methods with std::span parameters"
puts "✅ Default parameters in template methods"
puts "✅ Explicit constructors"
puts "✅ Deleted copy operations"
puts "✅ Noexcept move operations"
puts "✅ Const methods"
puts

puts "This C++ code demonstrates:"
puts "- Template class Buffer<T> with template methods"
puts "- OpenGL buffer management with RAII"
puts "- Type-safe data upload with std::span<T>"
puts "- Modern C++ features (move semantics, noexcept)"
puts "- Template method specialization for different data types"
puts

puts "Demo completed successfully! 🎉"

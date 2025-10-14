#!/usr/bin/env ruby
# frozen_string_literal: true

# OpenGL Result Example - Aurora DSL
# Demonstrates modern error handling with std::expected and pattern matching

require_relative "../lib/cpp_ast"

include CppAst::Builder::DSL

puts "=== OpenGL Result Example ==="
puts "Demonstrating modern error handling with Aurora DSL"
puts

# Generate modern error handling patterns
ast = program(
  # Include directives
  expr_stmt(call(id("include"), string('"<epoxy/gl.h>"'))),
  expr_stmt(call(id("include"), string('"<string>"'))),
  expr_stmt(call(id("include"), string('"<optional>"'))),
  expr_stmt(call(id("include"), string('"<expected>"'))),
  expr_stmt(call(id("include"), string('"<span>"'))),
  
  # Namespace declaration
  namespace_decl("gtkgl::gl", [
    
    # Shader compilation result - Sum type
    sum_type("ShaderResult",
      case_struct("Success", field_def("shader", "Shader")),
      case_struct("CompileError", field_def("message", "std::string")),
      case_struct("InvalidSource", field_def("reason", "std::string"))
    ),
    
    # Program linking result - Sum type
    sum_type("ProgramResult",
      case_struct("Success", field_def("program", "ShaderProgram")),
      case_struct("LinkError", field_def("message", "std::string")),
      case_struct("ValidationError", field_def("details", "std::string"))
    ),
    
    # Buffer creation result - Sum type
    sum_type("BufferResult",
      case_struct("Success", field_def("buffer", "Buffer")),
      case_struct("AllocationError", field_def("size", "size_t")),
      case_struct("InvalidType", field_def("type", "GLenum"))
    ),
    
    # Safe shader compilation function
    function_decl(
      result_of("Shader", "std::string"),
      "compile_shader_safe",
      [
        param("Shader::Type", "type"),
        param(borrowed("std::string"), "source")
      ],
      block(
        # Create shader
        var_decl("GLuint", "shader = glCreateShader(static_cast<GLenum>(type))"),
        
        # Set source
        var_decl("const char*", "src = source.c_str()"),
        expr_stmt(call(id("glShaderSource"), id("shader"), int(1), unary("&", id("src")), id("nullptr"))),
        expr_stmt(call(id("glCompileShader"), id("shader"))),
        
        # Check compilation
        var_decl("GLint", "success"),
        expr_stmt(call(id("glGetShaderiv"), id("shader"), id("GL_COMPILE_STATUS"), unary("&", id("success")))),
        
        # Pattern matching on result
        if_stmt(
          binary("==", id("success"), id("GL_FALSE")),
          block(
            # Get error message
            var_decl("GLint", "log_length"),
            expr_stmt(call(id("glGetShaderiv"), id("shader"), id("GL_INFO_LOG_LENGTH"), unary("&", id("log_length")))),
            
            var_decl("std::vector<char>", "log(log_length)"),
            expr_stmt(call(id("glGetShaderInfoLog"), id("shader"), id("log_length"), id("nullptr"), call(member(id("log"), ".", "data")))),
            
            var_decl("std::string", "error_msg(log.begin(), log.end())"),
            expr_stmt(call(id("glDeleteShader"), id("shader"))),
            return_stmt(err(id("error_msg")))
          ),
          block(
            # Success case
            var_decl("Shader", "shader_obj(type, source)"),
            return_stmt(ok(id("shader_obj")))
          )
        )
      )
    ),
    
    # Safe program linking function
    function_decl(
      result_of("ShaderProgram", "std::string"),
      "link_program_safe",
      [
        param(span_of(borrowed("Shader")), "shaders")
      ],
      block(
        # Create program
        var_decl("ShaderProgram", "program"),
        
        # Attach shaders
        for_stmt(
          "auto it = shaders.begin()",
          binary("!=", id("it"), call(member(id("shaders"), ".", "end"))),
          unary_post("++", id("it")),
          block(
            expr_stmt(call(member(id("program"), ".", "attach"), deref(id("it"))))
          )
        ),
        
        # Link program
        var_decl("bool", "link_success = program.link()"),
        
        # Pattern matching on link result
        if_stmt(
          binary("!", id("link_success")),
          block(
            var_decl("std::string", "error_msg = program.link_error().value_or(\"Unknown link error\")")),
            return_stmt(err(id("error_msg")))
          ),
          block(
            return_stmt(ok(id("program")))
          )
        )
      )
    ),
    
    # Safe buffer creation function
    function_decl(
      result_of("Buffer", "std::string"),
      "create_buffer_safe",
      [
        param("Buffer::Type", "type"),
        param(span_of("const float"), "data")
      ],
      block(
        # Validate input
        if_stmt(
          binary("==", call(member(id("data"), ".", "size")), int(0)),
          block(
            return_stmt(err(string('"Empty data provided"'))))
          )
        ),
        
        # Check for valid type
        if_stmt(
          binary("||",
            binary("!=", id("type"), member(id("Buffer::Type"), "::", "Array")),
            binary("!=", id("type"), member(id("Buffer::Type"), "::", "ElementArray"))
          ),
          block(
            return_stmt(err(string('"Invalid buffer type"'))))
          )
        ),
        
        # Create buffer
        var_decl("Buffer", "buffer(type)"),
        expr_stmt(call(member(id("buffer"), ".", "data"), id("data"))),
        
        # Check if buffer is valid
        if_stmt(
          binary("!", call(member(id("buffer"), ".", "is_valid"))),
          block(
            return_stmt(err(string('"Failed to create buffer"'))))
          ),
          block(
            return_stmt(ok(id("buffer")))
          )
        )
      )
    ),
    
    # Safe uniform setting with error handling
    function_decl(
      option_of("std::string"),
      "set_uniform_safe",
      [
        param("GLuint", "program"),
        param(borrowed("std::string"), "name"),
        param(span_of("const float"), "values")
      ],
      block(
        # Get uniform location
        var_decl("GLint", "location = glGetUniformLocation(program, name.c_str())"),
        
        # Check if uniform exists
        if_stmt(
          binary("<", id("location"), int(0)),
          block(
            return_stmt(some(string('"Uniform not found: "') + id("name")))
          )
        ),
        
        # Validate values array
        if_stmt(
          binary("==", call(member(id("values"), ".", "size")), int(0)),
          block(
            return_stmt(some(string('"Empty values array"'))))
          )
        ),
        
        # Set uniform based on count
        match_expr(call(member(id("values"), ".", "size")),
          arm("1", [], block(
            expr_stmt(call(id("glUniform1f"), id("location"), call(member(id("values"), ".", "data"), int(0))))
          )),
          arm("2", [], block(
            expr_stmt(call(id("glUniform2f"), id("location"), 
              call(member(id("values"), ".", "data"), int(0)),
              call(member(id("values"), ".", "data"), int(1))
            ))
          )),
          arm("3", [], block(
            expr_stmt(call(id("glUniform3f"), id("location"),
              call(member(id("values"), ".", "data"), int(0)),
              call(member(id("values"), ".", "data"), int(1)),
              call(member(id("values"), ".", "data"), int(2))
            ))
          )),
          arm("4", [], block(
            expr_stmt(call(id("glUniform4f"), id("location"),
              call(member(id("values"), ".", "data"), int(0)),
              call(member(id("values"), ".", "data"), int(1)),
              call(member(id("values"), ".", "data"), int(2)),
              call(member(id("values"), ".", "data"), int(3))
            ))
          )),
          arm("_", [], block(
            return_stmt(some(string('"Unsupported uniform size"'))))
          )
        ),
        
        return_stmt(none())
      )
    ),
    
    # High-level safe rendering function
    function_decl(
      result_of("void", "std::string"),
      "render_safe",
      [
        param(borrowed("ShaderProgram"), "program"),
        param(span_of(borrowed("Buffer")), "buffers"),
        param(span_of("const float"), "uniforms")
      ],
      block(
        # Use program
        expr_stmt(call(member(id("program"), ".", "use"))),
        
        # Bind buffers
        for_stmt(
          "auto it = buffers.begin()",
          binary("!=", id("it"), call(member(id("buffers"), ".", "end"))),
          unary_post("++", id("it")),
          block(
            expr_stmt(call(member(deref(id("it")), ".", "bind")))
          )
        ),
        
        # Set uniforms
        var_decl("size_t", "uniform_index = 0"),
        for_stmt(
          "auto it = uniforms.begin()",
          binary("!=", id("it"), call(member(id("uniforms"), ".", "end"))),
          unary_post("++", id("it")),
          block(
            var_decl("std::string", "uniform_name = \"uniform_\" + std::to_string(uniform_index)")),
            var_decl("auto", "result = set_uniform_safe(program.handle(), uniform_name, *it)"),
            
            # Pattern matching on result
            match_expr(id("result"),
              arm("Some", ["error_msg"], block(
                return_stmt(err(id("error_msg")))
              )),
              arm("None", [], block(
                expr_stmt(binary("++", id("uniform_index")))
              ))
            )
          )
        ),
        
        # Perform actual rendering
        expr_stmt(call(id("glDrawArrays"), id("GL_TRIANGLES"), int(0), int(6))),
        
        return_stmt(ok(id("void")))
      )
    )
  ])
)

puts "Generated C++ Code:"
puts "=" * 80
puts ast.to_source
puts "=" * 80

puts
puts "Features demonstrated:"
puts "✅ Sum types for error handling (ShaderResult, ProgramResult, BufferResult)"
puts "✅ std::expected for safe function returns"
puts "✅ std::optional for nullable values"
puts "✅ Pattern matching with match_expr and arm"
puts "✅ Error propagation with ok() and err()"
puts "✅ Safe resource management"
puts "✅ Type-safe error messages"
puts "✅ Modern C++23 error handling patterns"

puts
puts "Benefits of using Aurora DSL for error handling:"
puts "• Explicit error handling - no exceptions"
puts "• Type-safe error propagation"
puts "• Pattern matching for error cases"
puts "• Compile-time error checking"
puts "• Resource safety with RAII"
puts "• Modern C++23 best practices"
puts "• Easy testing of error paths"
puts "• Clear error message types"

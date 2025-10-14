# frozen_string_literal: true

require "test_helper"

class InlineMethodsTest < Minitest::Test
  include CppAst::Builder::DSL

  def test_inline_method_basic
    ast = function_decl("GLuint", "handle", [], block())
      .inline_body(block(return_stmt(id("shader_"))))
    cpp_code = ast.to_source
    assert_includes cpp_code, "inline GLuint handle"
    assert_includes cpp_code, "return shader_"
  end

  def test_inline_method_with_const_noexcept
    ast = function_decl("bool", "is_valid", [], block())
      .inline_body(block(return_stmt(binary("!=", id("shader_"), int(0)))))
      .const()
      .noexcept()
    cpp_code = ast.to_source
    assert_includes cpp_code, "inline bool is_valid"
    assert_includes cpp_code, "const noexcept"
    assert_includes cpp_code, "shader_ != 0"
  end

  def test_inline_method_with_return_type
    ast = function_decl("GLuint", "get_handle", [], block())
      .inline_body(block(return_stmt(id("buffer_"))))
      .const()
      .noexcept()
    cpp_code = ast.to_source
    assert_includes cpp_code, "inline GLuint get_handle"
    assert_includes cpp_code, "const noexcept"
    assert_includes cpp_code, "return buffer_"
  end

  def test_inline_method_with_parameters
    ast = function_decl("void", "set_uniform", [param("const std::string&", "name"), param("int", "value")], block())
      .inline_body(block(
        expr_stmt(call(id("glUniform1i"), [
          call(id("glGetUniformLocation"), [id("program_"), id("name")]),
          id("value")
        ]))
      ))
      .const()
    cpp_code = ast.to_source
    assert_includes cpp_code, "inline void set_uniform"
    assert_includes cpp_code, "const"
    assert_includes cpp_code, "glUniform1i"
  end

  def test_inline_method_with_multiple_modifiers
    ast = function_decl("", "Vec2", [param("float", "x"), param("float", "y")], block())
      .inline_body(block(
        expr_stmt(binary("=", id("x"), id("x_"))),
        expr_stmt(binary("=", id("y"), id("y_")))
      ))
      .explicit()
      .constexpr()
    cpp_code = ast.to_source
    assert_includes cpp_code, "constexpr explicit inline"
    assert_includes cpp_code, "x = x_"
    assert_includes cpp_code, "y = y_"
  end

  def test_inline_method_static_constexpr
    ast = function_decl("Color", "white", [], block())
      .inline_body(block(return_stmt(binary("=", id("r"), float(1.0)))))
      .static()
      .constexpr()
    cpp_code = ast.to_source
    assert_includes cpp_code, "constexpr static inline Color white"
    assert_includes cpp_code, "1.0"
  end
end

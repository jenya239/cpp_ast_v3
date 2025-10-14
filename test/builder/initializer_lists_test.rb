# frozen_string_literal: true

require "test_helper"

class InitializerListsTest < Minitest::Test
  include CppAst::Builder::DSL

  def test_constructor_with_initializer_list
    ast = function_decl("", "Vec2", [param("float", "x_"), param("float", "y_")], block())
      .with_initializer_list("x(x_), y(y_)")
      .constexpr()
    cpp_code = ast.to_source
    assert_includes cpp_code, "constexpr"
    assert_includes cpp_code, ": x(x_), y(y_)"
  end

  def test_constructor_with_single_initializer
    ast = function_decl("", "Rect", [param("float", "x_"), param("float", "y_"), param("float", "w_"), param("float", "h_")], block())
      .with_initializer_list("x(x_), y(y_), width(w_), height(h_)")
    cpp_code = ast.to_source
    assert_includes cpp_code, "Rect"
    assert_includes cpp_code, ": x(x_), y(y_), width(w_), height(h_)"
  end

  def test_constructor_with_base_class_initializer
    ast = function_decl("", "Derived", [param("int", "value")], block())
      .with_initializer_list("Base(value), member_(0)")
    cpp_code = ast.to_source
    assert_includes cpp_code, "Derived"
    assert_includes cpp_code, ": Base(value), member_(0)"
  end

  def test_constructor_with_delegating_initializer
    ast = function_decl("", "MyClass", [param("int", "value")], block())
      .with_initializer_list("MyClass(value, 0)")
    cpp_code = ast.to_source
    assert_includes cpp_code, "MyClass"
    assert_includes cpp_code, ": MyClass(value, 0)"
  end

  def test_constructor_with_initializer_and_modifiers
    ast = function_decl("", "Color", [param("float", "r_"), param("float", "g_"), param("float", "b_"), param("float", "a_")], block())
      .with_initializer_list("r(r_), g(g_), b(b_), a(a_)")
      .explicit()
      .constexpr()
    cpp_code = ast.to_source
    assert_includes cpp_code, "constexpr explicit"
    assert_includes cpp_code, ": r(r_), g(g_), b(b_), a(a_)"
  end

  def test_constructor_with_complex_initializer
    ast = function_decl("", "Buffer", [param("Type", "type")], block())
      .with_initializer_list("buffer_(0), type_(type)")
    cpp_code = ast.to_source
    assert_includes cpp_code, "Buffer"
    assert_includes cpp_code, ": buffer_(0), type_(type)"
  end

  def test_constructor_with_initializer_and_body
    ast = function_decl("", "Shader", [param("Type", "type"), param("const std::string&", "source")], 
      block(
        expr_stmt(call(id("glCreateShader"), [id("type")])),
        expr_stmt(call(id("glShaderSource"), [id("shader_"), int(1), id("source"), id("nullptr")])),
        expr_stmt(call(id("glCompileShader"), [id("shader_")]))
      ))
      .with_initializer_list("shader_(0)")
    cpp_code = ast.to_source
    assert_includes cpp_code, "Shader"
    assert_includes cpp_code, ": shader_(0)"
    assert_includes cpp_code, "glCreateShader"
  end
end
